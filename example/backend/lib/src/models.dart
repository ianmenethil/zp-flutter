/// Checkout domain models and ZenPay status mapping.
library;

import 'package:zenpay_dart/zenpay_dart.dart' show ZpPaymentStatus;

/// Presentation environment the checkout session was initiated from.
///
/// Only `web` and `mobile`: iframe (`webFrame`) checkout is disabled
/// project-wide (`docs/adr/ADR-002-system-browser-not-webview.md`).
enum CheckoutClient {
  /// Browser-based checkout (`window.open`/redirect flow).
  web,

  /// Flutter app checkout (system browser / embedded WebView).
  mobile;

  /// Parses a wire string (`'web'`/`'mobile'`) into a [CheckoutClient], or
  /// `null` if it matches none.
  static CheckoutClient? tryParse(String value) {
    for (final client in CheckoutClient.values) {
      if (client.name == value) return client;
    }
    return null;
  }
}

/// Merchant-facing payment lifecycle state returned during status polling.
enum MerchantPaymentStatus {
  /// Attempt recorded, checkout URL not yet built.
  created,

  /// Checkout URL built and returned to the client.
  sessionCreated,

  /// Browser returned to `/return`; not yet callback-verified.
  browserReturned,

  /// Callback verified, ZenPay reports the payment as pending/in progress.
  pending,

  /// Callback verified, payment succeeded.
  successful,

  /// Callback verified, payment failed.
  failed,

  /// Callback verified, payment was cancelled.
  cancelled,

  /// Callback verified, ZenPay reported an error/suppressed state.
  error,

  /// No callback received yet, or its status code was unrecognized.
  unknown,
}

/// Looks up the [ZpPaymentStatus] matching a raw ZenPay wire status code.
ZpPaymentStatus? _zpPaymentStatusFromWireValue(int value) {
  for (final status in ZpPaymentStatus.values) {
    if (status.wireValue == value) return status;
  }
  return null;
}

/// Translates a ZenPay wire status code into a [MerchantPaymentStatus].
MerchantPaymentStatus mapZenPayStatus(int statusCode) =>
    switch (_zpPaymentStatusFromWireValue(statusCode)) {
      ZpPaymentStatus.pending ||
      ZpPaymentStatus.inProgress => MerchantPaymentStatus.pending,
      ZpPaymentStatus.successful => MerchantPaymentStatus.successful,
      ZpPaymentStatus.failed => MerchantPaymentStatus.failed,
      ZpPaymentStatus.cancelled => MerchantPaymentStatus.cancelled,
      ZpPaymentStatus.error ||
      ZpPaymentStatus.suppressed => MerchantPaymentStatus.error,
      null => MerchantPaymentStatus.unknown,
    };

/// Tracks the payment identifier, launch parameters, and verified callback
/// results for one ZenPay checkout attempt. Its identity is its
/// [merchantUniquePaymentId] — there is no separate attempt id; an example
/// app that needs a per-attempt handle uses the MUPID directly.
class CheckoutAttempt {
  /// Creates a [CheckoutAttempt].
  CheckoutAttempt({
    required this.merchantUniquePaymentId,
    required this.idempotencyKey,
    required this.mode,
    required this.client,
    required this.customerName,
    required this.customerEmail,
    required this.zenPayTimestamp,
    required this.createdAt,
    required this.status,
    this.amount,
    this.customerReference,
    this.contactNumber,
    this.checkoutUrl,
    this.paymentReference,
    this.preauthReference,
    this.tokenReference,
    this.failureCode,
    this.failureReason,
    this.verifiedCallbackReference,
    this.verifiedCallbackStatusCode,
    this.verifiedCallbackPayload,
  });

  /// ZenPay's per-attempt idempotency key. This attempt's identity.
  final String merchantUniquePaymentId;

  /// `Idempotency-Key` header value that created this attempt.
  final String idempotencyKey;

  /// ZenPay plugin operation mode (0: Make Payment, 1: Tokenise, 2: Custom, 3: PreAuth).
  final int mode;

  /// Presentation environment the session was created for.
  final CheckoutClient client;

  /// Customer display name.
  final String customerName;

  /// Customer email address.
  final String customerEmail;

  /// The ZenPay timestamp fixed when this attempt was prepared — reused on
  /// every exchange of the same checkout token so the fingerprint (and
  /// resulting checkout URL) is byte-identical on replay.
  final String zenPayTimestamp;

  /// When this attempt was first created.
  final DateTime createdAt;

  /// Current merchant-facing lifecycle status.
  final MerchantPaymentStatus status;

  /// Amount in dollars, resolved by the backend. `null` when this attempt
  /// carries no amount at all (Tokenise with no product). For Tokenise
  /// (mode 1) with a product, this is a fee/pricing figure shown to the
  /// customer, never charged — see `session_service.dart`'s `_isPaymentLike`.
  final num? amount;

  /// Optional customer-facing reference.
  final String? customerReference;

  /// Optional customer contact number.
  final String? contactNumber;

  /// The generated ZenPay HCP launch URL, once built.
  final String? checkoutUrl;

  /// Verified payment reference (modes 0/2 only).
  final String? paymentReference;

  /// Verified pre-authorization reference (mode 3 only).
  final String? preauthReference;

  /// Verified token reference (mode 1 only).
  final String? tokenReference;

  /// Failure code from the verified callback, if any.
  final String? failureCode;

  /// Failure reason from the verified callback, if any.
  final String? failureReason;

  /// Reference echoed by the last verified callback, used to detect a
  /// conflicting replay.
  final String? verifiedCallbackReference;

  /// Status code from the last verified callback, used to detect a
  /// conflicting replay.
  final int? verifiedCallbackStatusCode;

  /// The entire last verified callback body ZenPay posted —
  /// `{response, validationCode}` — unfiltered. Safe to surface to the
  /// client per this repo's logging policy (see `server_app.dart`'s
  /// `logEvent` doc comment).
  final Map<String, Object?>? verifiedCallbackPayload;

  /// Returns a copy with the given fields replaced; omitted fields keep
  /// their current value.
  CheckoutAttempt copyWith({
    MerchantPaymentStatus? status,
    String? checkoutUrl,
    String? paymentReference,
    String? preauthReference,
    String? tokenReference,
    String? failureCode,
    String? failureReason,
    String? verifiedCallbackReference,
    int? verifiedCallbackStatusCode,
    Map<String, Object?>? verifiedCallbackPayload,
  }) => CheckoutAttempt(
    merchantUniquePaymentId: merchantUniquePaymentId,
    idempotencyKey: idempotencyKey,
    mode: mode,
    client: client,
    customerName: customerName,
    customerEmail: customerEmail,
    zenPayTimestamp: zenPayTimestamp,
    createdAt: createdAt,
    status: status ?? this.status,
    amount: amount,
    customerReference: customerReference,
    contactNumber: contactNumber,
    checkoutUrl: checkoutUrl ?? this.checkoutUrl,
    paymentReference: paymentReference ?? this.paymentReference,
    preauthReference: preauthReference ?? this.preauthReference,
    tokenReference: tokenReference ?? this.tokenReference,
    failureCode: failureCode ?? this.failureCode,
    failureReason: failureReason ?? this.failureReason,
    verifiedCallbackReference:
        verifiedCallbackReference ?? this.verifiedCallbackReference,
    verifiedCallbackStatusCode:
        verifiedCallbackStatusCode ?? this.verifiedCallbackStatusCode,
    verifiedCallbackPayload:
        verifiedCallbackPayload ?? this.verifiedCallbackPayload,
  );
}

/// Validated `POST /api/v1/checkout/token` request body.
class PrepareCheckoutBody {
  /// Creates a [PrepareCheckoutBody].
  const PrepareCheckoutBody({
    required this.customerName,
    required this.customerEmail,
    required this.client,
    this.mode,
    this.paymentAmount,
    this.customerReference,
    this.contactNumber,
  });

  /// Customer display name.
  final String customerName;

  /// Customer email address.
  final String customerEmail;

  /// Presentation environment the session is being created for.
  final CheckoutClient client;

  /// ZenPay plugin operation mode; defaults to Make Payment (0) if omitted.
  final int? mode;

  /// Client-supplied amount. Required (any positive value) for modes 0, 2,
  /// and 3; unused for mode 1.
  final num? paymentAmount;

  /// Optional customer-facing reference.
  final String? customerReference;

  /// Optional customer contact number.
  final String? contactNumber;
}

/// Launch data returned to the client app from `POST /api/v1/checkout/exchange`.
class ExchangeCheckoutResponse {
  /// Creates an [ExchangeCheckoutResponse].
  const ExchangeCheckoutResponse({required this.checkoutUrl});

  /// The ZenPay HCP launch URL to present to the customer.
  final String checkoutUrl;

  /// Serializes to the `POST /api/v1/checkout/exchange` response body shape.
  Map<String, Object?> toJson() => {'checkoutUrl': checkoutUrl};
}

/// Controlled HTTP exception carrying a status code and machine-readable code.
///
/// Thrown by request handlers and turned into a `{"error": code}` JSON
/// response by `buildHandler`'s catch clause.
class HttpError implements Exception {
  /// Creates an [HttpError] that maps to the given HTTP [statusCode].
  HttpError(this.statusCode, this.code);

  /// HTTP status code to respond with.
  final int statusCode;

  /// Machine-readable error identifier sent as the response body's `error` field.
  final String code;

  @override
  String toString() => code;
}
