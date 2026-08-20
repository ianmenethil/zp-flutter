/// Two-step checkout: prepare a signed capability, then exchange it for a
/// ZenPay checkout URL.
///
/// No outbound network call happens at launch time — the launch URL is
/// computed locally via `package:zenpay_dart`. `merchantUniquePaymentId`
/// (MUPID) and the ZenPay timestamp are minted once, at prepare time, and
/// carried inside the checkout token — exchanging the same token twice
/// always rebuilds the same attempt rather than minting a new one.
library;

import 'package:zenpay_dart/zenpay_dart.dart';

import 'package:zenpay_example_backend/src/attempt_store.dart';
import 'package:zenpay_example_backend/src/checkout_token.dart'
    show CheckoutTokenFailure, CheckoutTokenPayload, CheckoutTokenVerified, createCheckoutToken, verifyCheckoutToken;
import 'package:zenpay_example_backend/src/config.dart';
import 'package:zenpay_example_backend/src/models.dart';
import 'package:zenpay_example_backend/src/token_keys.dart' show callbackTokenKey, checkoutTokenKey;

/// Path ZenPay redirects the browser back to after checkout.
const returnPath = '/return';

/// Path ZenPay POSTs the server-to-server callback to.
const callbacksPath = '/api/v1/callbacks';

/// The return URI for [attempt]'s client kind.
///
/// Mobile resolves to a path on this backend's own public base URL, intended
/// to be verified as an Android App Link / iOS Universal Link once the real
/// app ships one — that domain verification (`assetlinks.json`) isn't part
/// of this minimal backend yet.
Uri appReturnUriFor(CheckoutAttempt attempt, AppConfig config) =>
    attempt.client == CheckoutClient.mobile ? config.publicBaseUrl.resolve('/zenpay/app-return') : config.appReturnUriWeb;

/// Whether [mode] charges the customer (Make Payment, Custom Payment,
/// Pre-Auth) — gates `customerName`/`customerReference`, not [amount].
/// Tokenise (mode 1) is never payment-like even when it carries a resolved
/// [amount]: that amount is shown for pricing/fee display, never charged.
bool _isPaymentLike(int mode) => mode == 0 || mode == 2 || mode == 3;

/// Resolves the trusted amount for [mode] from [paymentAmount]. [mode] is
/// assumed already validated to 0–3; Tokenise (mode 1) takes no amount, every
/// other mode requires a positive client-supplied amount. The fingerprint
/// still hashes `"0"` for Custom Payment regardless of what's sent
/// (`zenpay_dart`'s `resolveZpHashAmountField`), unchanged here.
num? _resolveAmount(int mode, num? paymentAmount) {
  if (mode == 1) return null;
  if (paymentAmount == null || paymentAmount <= 0) {
    throw HttpError(400, 'INVALID_CHECKOUT_AMOUNT');
  }
  return paymentAmount;
}

/// Throws [HttpError] `409` if a replayed `idempotencyKey` request's core
/// order fields don't match the [existing] attempt.
void _requireIdempotentMatch(
  CheckoutAttempt existing,
  PrepareCheckoutBody body,
  int mode,
) {
  if (existing.customerEmail != body.customerEmail ||
      existing.customerName != body.customerName ||
      existing.mode != mode ||
      existing.client != body.client ||
      (mode == 2 && existing.amount != body.paymentAmount)) {
    throw HttpError(409, 'IDEMPOTENCY_KEY_REUSED');
  }
}

/// Mints a checkout token carrying [attempt]'s immutable fields.
String _mintCheckoutToken(CheckoutAttempt attempt, AppConfig config) => createCheckoutToken(
  CheckoutTokenPayload(
    merchantUniquePaymentId: attempt.merchantUniquePaymentId,
    mode: attempt.mode,
    client: attempt.client,
    customerName: attempt.customerName,
    customerEmail: attempt.customerEmail,
    timestamp: attempt.zenPayTimestamp,
    amount: attempt.amount,
    customerReference: attempt.customerReference,
    contactNumber: attempt.contactNumber,
  ),
  checkoutTokenKey(config),
  expiresInSeconds: config.checkoutTokenTtlSeconds,
);

/// Step 1 — `POST /api/v1/checkout/token`. Validates, resolves the trusted
/// amount, mints a fresh MUPID/timestamp, persists a pending
/// [CheckoutAttempt], and returns a signed checkout token. A repeated
/// [idempotencyKey] re-mints a token for the *same* attempt rather than
/// creating a new one.
String prepareCheckout(
  PrepareCheckoutBody body,
  String idempotencyKey,
  AppConfig config,
  AttemptStore store,
) {
  final mode = body.mode ?? 0;

  final existing = store.getByIdempotencyKey(idempotencyKey);
  if (existing != null) {
    _requireIdempotentMatch(existing, body, mode);
    return _mintCheckoutToken(existing, config);
  }

  final amount = _resolveAmount(mode, body.paymentAmount);

  final attempt = CheckoutAttempt(
    merchantUniquePaymentId: createZpMupid().value,
    idempotencyKey: idempotencyKey,
    mode: mode,
    client: body.client,
    customerName: body.customerName,
    customerEmail: body.customerEmail,
    zenPayTimestamp: createZpTimestamp().value,
    createdAt: DateTime.now().toUtc(),
    status: MerchantPaymentStatus.created,
    amount: amount,
    customerReference: body.customerReference,
    contactNumber: body.contactNumber,
  );
  store.create(attempt);

  return _mintCheckoutToken(attempt, config);
}

/// Step 2 — `POST /api/v1/checkout/exchange`. Verifies the checkout token,
/// and builds (or, on replay, reuses) the ZenPay checkout URL for the
/// attempt it names.
ExchangeCheckoutResponse exchangeCheckout(
  String checkoutToken,
  AppConfig config,
  AttemptStore store,
) {
  final payload = switch (verifyCheckoutToken(
    checkoutToken,
    checkoutTokenKey(config),
  )) {
    CheckoutTokenVerified(:final payload) => payload,
    CheckoutTokenFailure() => throw HttpError(401, 'CHECKOUT_TOKEN_INVALID'),
  };

  final attempt = store.getByMerchantPaymentId(payload.merchantUniquePaymentId);
  if (attempt == null) throw HttpError(404, 'CHECKOUT_ATTEMPT_NOT_FOUND');

  final existingUrl = attempt.checkoutUrl;
  if (existingUrl != null) {
    // Replay of an already-exchanged token: same attempt, no new one built.
    return ExchangeCheckoutResponse(checkoutUrl: existingUrl);
  }

  final checkoutUrl = _buildCheckoutUrl(
    merchantUniquePaymentId: payload.merchantUniquePaymentId,
    timestamp: payload.timestamp,
    mode: payload.mode,
    amount: payload.amount,
    customerName: payload.customerName,
    customerEmail: payload.customerEmail,
    customerReference: payload.customerReference,
    contactNumber: payload.contactNumber,
    config: config,
  );

  final updated = store.replace(
    attempt.merchantUniquePaymentId,
    attempt.copyWith(
      checkoutUrl: checkoutUrl.toString(),
      status: MerchantPaymentStatus.sessionCreated,
    ),
  );

  return ExchangeCheckoutResponse(checkoutUrl: updated.checkoutUrl!);
}

/// Computes the SHA3-512 fingerprint and builds the validated HCP launch URL.
Uri _buildCheckoutUrl({
  required String merchantUniquePaymentId,
  required String timestamp,
  required int mode,
  required num? amount,
  required String customerName,
  required String customerEmail,
  required String? customerReference,
  required String? contactNumber,
  required AppConfig config,
}) {
  final credentials = config.zenPay.credentials;
  final pluginMode = ZpPluginMode.fromWireValue(mode);

  // [amount] is passed through as-is, not pre-resolved per mode: the SDK's
  // own `resolveZpHashAmountField` already hashes "0" for Custom Payment
  // regardless of the value, and "0" for Tokenise only when amount is null
  // — Tokenise WITH a resolved product amount hashes that real amount, so
  // it can be shown as a pricing/fee figure without being charged.
  final fingerprint = switch (createZpFingerprint(
    ZpFingerprintInput(
      apiKey: credentials.apiKey,
      username: credentials.username,
      password: credentials.password,
      mode: pluginMode,
      paymentAmount: amount,
      merchantUniquePaymentId: ZpMupid(merchantUniquePaymentId),
      timestamp: ZpTimestamp(timestamp),
    ),
  )) {
    ZpFingerprintSuccess(:final fingerprint) => fingerprint,
    ZpFingerprintFailure() => throw ZenPaySessionException(
      'ZENPAY_FINGERPRINT_FAILED',
    ),
  };

  // Carries the mupid as a signed claim, so `/return` and the status lookup
  // can trust it without a caller-supplied, unverified id.
  final returnToken = createZpCallbackUrlToken(
    ZpCallbackUrlTokenPayload(
      mode: pluginMode,
      merchantUniquePaymentId: merchantUniquePaymentId,
      timestamp: timestamp,
      paymentAmount: amount,
    ),
    callbackTokenKey(config),
    ZpCallbackUrlTokenOptions(
      expiresInSeconds: config.checkoutStatusTtlMinutes * 60,
    ),
  );

  final isPaymentLike = _isPaymentLike(mode);
  final isMakePayment = mode == 0;
  final returnUrl = config.publicBaseUrl.replace(
    path: returnPath,
    queryParameters: {'t': returnToken},
  );

  final authoriseRequest = ZpCheckoutOptions(
    url: config.zenPay.hppEndpointUrl.toString(),
    apiKey: credentials.apiKey,
    fingerprint: fingerprint,
    merchantCode: credentials.merchantCode,
    mode: pluginMode,
    timestamp: ZpTimestamp(timestamp),
    merchantUniquePaymentId: ZpMupid(merchantUniquePaymentId),
    customerEmail: customerEmail,
    redirectUrl: returnUrl.toString(),
    callbackUrl: config.publicBaseUrl.resolve(callbacksPath).toString(),
    redirectOnError: true,
    customerName: isPaymentLike ? customerName : null,
    customerReference: isPaymentLike ? customerReference : null,
    // Sent whenever resolved, not gated by isPaymentLike: Tokenise (mode 1)
    // with a product carries a non-null amount here too, for ZenPay to
    // show applicable fee/pricing without charging it.
    paymentAmount: amount,
    contactNumber: contactNumber,
    allowApplePayOneOffPayment: isMakePayment,
    allowGooglePayOneOffPayment: isMakePayment ? true : null,
    sendConfirmationEmailToMerchant: false,
    allowSaveCardUserOption: false,
  );

  final url = switch (createZpCheckoutUrl(authoriseRequest)) {
    ZpUrlSuccess(:final url) => url,
    ZpUrlFailure() => throw ZenPaySessionException(
      'ZENPAY_CHECKOUT_URL_FAILED',
    ),
  };
  return resolveCheckoutUrl(url, config);
}

/// Thrown when checkout session URL generation fails or violates security
/// allowlists.
class ZenPaySessionException implements Exception {
  /// Creates a [ZenPaySessionException] with a machine-readable [code].
  ZenPaySessionException(this.code);

  /// Machine-readable failure identifier.
  final String code;

  @override
  String toString() => code;
}

/// Validates that a generated launch URL uses HTTPS and targets an allowed host.
Uri resolveCheckoutUrl(String endpointUrl, AppConfig config) {
  final checkoutUrl = Uri.parse(endpointUrl);
  if (checkoutUrl.scheme != 'https') {
    throw ZenPaySessionException('ZENPAY_SESSION_ENDPOINT_NOT_HTTPS');
  }
  if (!config.zenPay.allowedCheckoutHosts.contains(
    checkoutUrl.host.toLowerCase(),
  )) {
    throw ZenPaySessionException('ZENPAY_RESOLVED_CHECKOUT_URL_NOT_ALLOWED');
  }
  return checkoutUrl;
}
