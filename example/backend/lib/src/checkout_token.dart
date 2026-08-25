/// Signed checkout-exchange capability tokens.
///
/// An example-backend concept, not part of the ZenPay SDK. `POST
/// /api/v1/checkout/token` mints one of these instead of directly returning
/// a ZenPay checkout URL: it binds every immutable input needed to build one
/// specific ZenPay attempt (the fresh `merchantUniquePaymentId` and
/// timestamp included) into a short-lived signed capability. `POST
/// /api/v1/checkout/exchange` verifies it and rebuilds the attempt from its
/// claims — never minting a new `merchantUniquePaymentId` itself — so
/// exchanging the same token twice always resolves to the same ZenPay
/// attempt rather than creating a second one.
///
/// Deliberately separate from `zenpay_dart`'s `ZpCallbackUrlToken` (`t`).
/// Both share the same secret-derivation root and codec, but
/// `token_keys.dart` signs each with its own `deriveTokenKey`-derived key,
/// so one can never verify — let alone decode — as the other; the `scope`
/// claim below is defense in depth on top of that, not the primary
/// separation.
library;

import 'package:zenpay_example_backend/src/models.dart' show CheckoutClient;
import 'package:zenpay_example_backend/src/signed_token.dart'
    show SignedTokenBadSignature, SignedTokenDecoded, SignedTokenMalformed, decodeSignedToken, encodeSignedToken;

const _scope = 'checkout:exchange';

const _keyScope = 'scope';
const _keyMupid = 'mupid';
const _keyMode = 'mode';
const _keyClient = 'client';
const _keyAmount = 'amount';
const _keyCustomerName = 'customerName';
const _keyCustomerEmail = 'customerEmail';
const _keyCustomerReference = 'customerReference';
const _keyContactNumber = 'contactNumber';
const _keyTimestamp = 'timestamp';
const _keyIssuedAt = 'iat';
const _keyExpiresAt = 'exp';

/// Immutable claims of a checkout token — everything `/checkout/exchange`
/// needs to deterministically rebuild the same ZenPay attempt on every
/// exchange of the same token.
class CheckoutTokenPayload {
  /// Creates a [CheckoutTokenPayload].
  const CheckoutTokenPayload({
    required this.merchantUniquePaymentId,
    required this.mode,
    required this.client,
    required this.customerName,
    required this.customerEmail,
    required this.timestamp,
    this.amount,
    this.customerReference,
    this.contactNumber,
  });

  /// The ZenPay attempt this token was minted for. Fixed at prepare time —
  /// exchanging this token never mints a different one.
  final String merchantUniquePaymentId;

  /// ZenPay plugin operation mode (0: Make Payment, 1: Tokenise, 2: Custom, 3: PreAuth).
  final int mode;

  /// Presentation environment the checkout was created for.
  final CheckoutClient client;

  /// Customer display name.
  final String customerName;

  /// Customer email address.
  final String customerEmail;

  /// The ZenPay timestamp fixed at prepare time — reused verbatim on every
  /// exchange so the fingerprint (and the resulting checkout URL) is
  /// byte-identical on replay.
  final String timestamp;

  /// Trusted amount in dollars, resolved by the backend at prepare time.
  /// `null` when this attempt carries no amount at all. For Tokenise
  /// (mode 1) with a product, this is a fee/pricing figure sent to ZenPay
  /// for display, never charged.
  final num? amount;

  /// Optional customer-facing reference.
  final String? customerReference;

  /// Optional customer contact number.
  final String? contactNumber;
}

/// Result of [verifyCheckoutToken].
sealed class CheckoutTokenResult {
  const CheckoutTokenResult();
}

/// A successfully verified and decoded checkout token.
final class CheckoutTokenVerified extends CheckoutTokenResult {
  /// Creates a [CheckoutTokenVerified] wrapping the recovered [payload].
  const CheckoutTokenVerified(this.payload);

  /// The recovered token payload.
  final CheckoutTokenPayload payload;
}

/// Why a checkout token failed verification.
enum CheckoutTokenFailureReason {
  /// The token could not be decoded into its expected shape.
  malformed,

  /// The signature does not match the supplied secret.
  badSignature,

  /// The token's expiration time is in the past.
  expired,

  /// The token decoded and verified, but is not a checkout-exchange token
  /// (e.g. a `t` return token presented in its place).
  wrongScope,
}

/// A failed checkout token verification.
final class CheckoutTokenFailure extends CheckoutTokenResult {
  /// Creates a [CheckoutTokenFailure] with the given [reason].
  const CheckoutTokenFailure(this.reason);

  /// Why verification failed.
  final CheckoutTokenFailureReason reason;
}

/// Mints a signed, stateless checkout token carrying [payload], valid for
/// [expiresInSeconds]. Keep this short-lived — it is the anonymous admission
/// boundary for creating a ZenPay attempt. [secret] is typically a
/// purpose-derived key from `token_keys.dart`, not the raw root secret.
String createCheckoutToken(CheckoutTokenPayload payload, Object secret, {required int expiresInSeconds}) {
  final issuedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  return encodeSignedToken({
    _keyScope: _scope,
    _keyMupid: payload.merchantUniquePaymentId,
    _keyMode: payload.mode,
    _keyClient: payload.client.name,
    _keyAmount: ?payload.amount,
    _keyCustomerName: payload.customerName,
    _keyCustomerEmail: payload.customerEmail,
    _keyCustomerReference: ?payload.customerReference,
    _keyContactNumber: ?payload.contactNumber,
    _keyTimestamp: payload.timestamp,
    _keyIssuedAt: issuedAt,
    _keyExpiresAt: issuedAt + expiresInSeconds,
  }, secret);
}

/// Verifies and decodes a token minted by [createCheckoutToken]. [secret]
/// must be the same key [createCheckoutToken] was called with.
CheckoutTokenResult verifyCheckoutToken(String token, Object secret) {
  final Map<String, Object?> data;
  switch (decodeSignedToken(token, secret)) {
    case SignedTokenDecoded(:final claims):
      data = claims;
    case SignedTokenBadSignature():
      return const CheckoutTokenFailure(CheckoutTokenFailureReason.badSignature);
    case SignedTokenMalformed():
      return const CheckoutTokenFailure(CheckoutTokenFailureReason.malformed);
  }

  final scope = data[_keyScope];
  if (scope is! String || scope != _scope) {
    return const CheckoutTokenFailure(CheckoutTokenFailureReason.wrongScope);
  }

  final mupid = data[_keyMupid];
  final modeValue = data[_keyMode];
  final clientValue = data[_keyClient];
  final amount = data[_keyAmount];
  final customerName = data[_keyCustomerName];
  final customerEmail = data[_keyCustomerEmail];
  final customerReference = data[_keyCustomerReference];
  final contactNumber = data[_keyContactNumber];
  final timestamp = data[_keyTimestamp];
  final issuedAt = data[_keyIssuedAt];
  final expiresAt = data[_keyExpiresAt];

  final client = clientValue is String ? CheckoutClient.tryParse(clientValue) : null;

  if (mupid is! String ||
      modeValue is! int ||
      client == null ||
      (amount != null && amount is! num) ||
      customerName is! String ||
      customerEmail is! String ||
      (customerReference != null && customerReference is! String) ||
      (contactNumber != null && contactNumber is! String) ||
      timestamp is! String ||
      issuedAt is! int ||
      expiresAt is! int) {
    return const CheckoutTokenFailure(CheckoutTokenFailureReason.malformed);
  }

  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  if (now >= expiresAt) {
    return const CheckoutTokenFailure(CheckoutTokenFailureReason.expired);
  }

  return CheckoutTokenVerified(
    CheckoutTokenPayload(
      merchantUniquePaymentId: mupid,
      mode: modeValue,
      client: client,
      customerName: customerName,
      customerEmail: customerEmail,
      timestamp: timestamp,
      amount: amount as num?,
      customerReference: customerReference as String?,
      contactNumber: contactNumber as String?,
    ),
  );
}
