import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// Fields required to generate an Authorise fingerprint.
class ZpFingerprintInput {
  /// Creates a [ZpFingerprintInput].
  const ZpFingerprintInput({
    required this.apiKey,
    required this.username,
    required this.password,
    required this.mode,
    required this.merchantUniquePaymentId,
    required this.timestamp,
    this.paymentAmount,
  });

  /// Merchant API key — hash field 1.
  final String apiKey;

  /// Merchant username — hash field 2.
  final String username;

  /// Merchant password — hash field 3.
  final String password;

  /// Payment operating mode — hash field 4.
  final ZpPluginMode mode;

  /// Per-payment Merchant Unique Payment ID — hash field 6.
  final ZpMupid merchantUniquePaymentId;

  /// UTC `yyyy-MM-ddTHH:mm:ss` timestamp — hash field 7.
  final ZpTimestamp timestamp;

  /// Payment amount in dollars — hash field 5.
  ///
  /// Optional for tokenisation. Modes 0, 2 and 3 require a positive amount.
  /// Mode 2 still hashes `"0"` regardless of the supplied amount.
  final Object? paymentAmount;
}

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
