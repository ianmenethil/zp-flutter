/// Models for outgoing Authorise fingerprint generation.
library;

import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// Fields required to generate an Authorise fingerprint.
class const ZpFingerprintInput({
  /// Merchant API key — hash field 1.
  required final String apiKey,

  /// Merchant username — hash field 2.
  required final String username,

  /// Merchant password — hash field 3.
  required final String password,

  /// Payment operating mode — hash field 4.
  required final ZpPluginMode mode,

  /// Per-payment Merchant Unique Payment ID — hash field 6.
  required final ZpMupid merchantUniquePaymentId,

  /// UTC `yyyy-MM-ddTHH:mm:ss` timestamp — hash field 7.
  required final ZpTimestamp timestamp,

  /// Payment amount in dollars — hash field 5.
  ///
  /// Optional for tokenisation. Modes 0 and 3 require a positive amount.
  /// Mode 2 accepts any value (including `0` or none) since it always
  /// hashes `"0"` regardless of the supplied amount.
  final Object? paymentAmount,
}) {}

/// Result of `createZpFingerprint`.
sealed class ZpFingerprintResult {
  /// Base constructor for fingerprint results.
  const ZpFingerprintResult();
}

/// A successfully generated fingerprint.
final class ZpFingerprintSuccess extends ZpFingerprintResult {
  /// Creates a [ZpFingerprintSuccess] result with the computed [fingerprint].
  const ZpFingerprintSuccess(this.fingerprint);

  /// 128-character lowercase SHA3-512 digest.
  final String fingerprint;
}

/// A fingerprint validation failure.
final class ZpFingerprintFailure extends ZpFingerprintResult {
  /// Creates a [ZpFingerprintFailure] result with the failure [message].
  const ZpFingerprintFailure(this.message);

  /// Why fingerprint creation failed.
  final String message;
}
