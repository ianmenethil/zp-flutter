import 'package:zenpay_dart/src/crypto.dart';

/// Merchant-known credentials, amount, and MUPID used to verify a callback.
class ZpVerifyCallbackContext {
  /// Creates a [ZpVerifyCallbackContext].
  const ZpVerifyCallbackContext({
    required this.apiKey,
    required this.username,
    required this.password,
    required this.paymentAmount,
    required this.merchantUniquePaymentId,
  });

  /// Merchant API key — hash field 1.
  final String apiKey;

  /// Merchant username — hash field 2.
  final String username;

  /// Merchant password — hash field 3.
  final String password;

  /// Payment amount in dollars, as launched — hash field 5.
  ///
  /// Ignored for mode 2, which always hashes `"0"`. May be `0` for mode 1.
  final Object paymentAmount;

  /// Per-payment idempotency key — hash field 6.
  ///
  /// When the callback echoes its own `merchantUniquePaymentId`, that value
  /// is also checked against this value.
  final ZpMupid merchantUniquePaymentId;
}

/// Result of `verifyZpCallback`.
///
/// Exhaustively pattern-match with a `switch` over [ZpCallbackVerified],
/// [ZpCallbackMalformed], and [ZpCallbackRejected].
sealed class ZpCallbackResult {
  /// Base constructor for callback verification results.
  const ZpCallbackResult();
}

/// An authentic callback — proves the callback was minted by ZenPay, nothing
/// more. Carries no data: you already hold the full callback body you passed
/// to `verifyZpCallback`, so read whatever fields you need from it directly.
final class ZpCallbackVerified extends ZpCallbackResult {
  /// Creates a [ZpCallbackVerified] result.
  const ZpCallbackVerified();
}

/// The callback body does not match the expected shape for its mode.
final class ZpCallbackMalformed extends ZpCallbackResult {
  /// Creates a [ZpCallbackMalformed] result with the error [message].
  const ZpCallbackMalformed(this.message);

  /// Why the callback was malformed.
  final String message;
}

/// The callback was shaped correctly but failed authenticity verification.
final class ZpCallbackRejected extends ZpCallbackResult {
  /// Creates a [ZpCallbackRejected] result with the rejection [message].
  const ZpCallbackRejected(this.message);

  /// Why the callback was rejected.
  final String message;
}
