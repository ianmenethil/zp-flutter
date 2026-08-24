/// Models for the signed callback URL token payload, options, and results.
library;

import 'package:zenpay_dart/src/crypto_utils.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// Payload stored inside a signed callback URL token.
class const ZpCallbackUrlTokenPayload({
  /// Payment operating mode.
  required final ZpPluginMode mode,

  /// Per-payment idempotency key.
  required final ZpMupid merchantUniquePaymentId,

  /// ISO 8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SS`).
  required final ZpTimestamp timestamp,

  /// Payment amount in dollars.
  final Object? paymentAmount,

  /// Arbitrary extra key-value pairs stored in the token payload.
  final Map<String, Object?> extra = const {},
}) {}

/// Options for token creation, such as expiration.
class const ZpCallbackUrlTokenOptions({
  /// Token lifetime in seconds.
  ///
  /// `null` means the token does not expire.
  final int? expiresInSeconds,
}) {}

/// Result of `verifyZpCallbackUrlToken`.
///
/// Exhaustively pattern-match with a `switch` over
/// [ZpCallbackUrlTokenVerified] and [ZpCallbackUrlTokenFailure].
sealed class ZpCallbackUrlTokenResult {
  /// Base constructor for callback URL token results.
  const ZpCallbackUrlTokenResult();
}

/// A successfully verified and decoded callback URL token.
final class ZpCallbackUrlTokenVerified extends ZpCallbackUrlTokenResult {
  /// Creates a [ZpCallbackUrlTokenVerified] result with the decoded [payload].
  const ZpCallbackUrlTokenVerified(this.payload);

  /// The recovered token payload.
  final ZpCallbackUrlTokenPayload payload;
}

/// Why a callback URL token failed verification.
enum ZpCallbackUrlTokenFailureReason {
  /// The token could not be decoded into its expected shape.
  malformed,

  /// The signature does not match the supplied secret.
  badSignature,

  /// The token's expiration time is in the past.
  expired,
}

/// A failed callback URL token verification.
final class ZpCallbackUrlTokenFailure extends ZpCallbackUrlTokenResult {
  /// Creates a [ZpCallbackUrlTokenFailure] result with the failure [reason].
  const ZpCallbackUrlTokenFailure(this.reason);

  /// Why verification failed.
  final ZpCallbackUrlTokenFailureReason reason;
}
