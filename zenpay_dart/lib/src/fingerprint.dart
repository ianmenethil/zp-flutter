/// Outgoing ZenPay HCP Authorise fingerprint generation.
library;

import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/enums.dart';

const _errApiKeyLength = 'apiKey must be at least $zpMinCredentialLength characters';
const _errUsernameLength = 'username must be at least $zpMinCredentialLength characters';
const _errPasswordLength = 'password must be at least $zpMinCredentialLength characters';
const _errMupidLength = 'merchantUniquePaymentId must be at least $zpMinCredentialLength characters';
const _errTimestampFormat = 'timestamp must be in YYYY-MM-DDTHH:MM:SS format';

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

/// Result of [createZpFingerprint].
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

(ZpCents?, ZpFingerprintFailure?) _validate(ZpFingerprintInput request) {
  if (request.apiKey.length < zpMinCredentialLength) {
    return (null, const ZpFingerprintFailure(_errApiKeyLength));
  }

  if (request.username.length < zpMinCredentialLength) {
    return (null, const ZpFingerprintFailure(_errUsernameLength));
  }

  if (request.password.length < zpMinCredentialLength) {
    return (null, const ZpFingerprintFailure(_errPasswordLength));
  }

  if (request.merchantUniquePaymentId.value.length < zpMinCredentialLength) {
    return (null, const ZpFingerprintFailure(_errMupidLength));
  }

  if (!isValidZpTimestamp(request.timestamp.value)) {
    return (null, const ZpFingerprintFailure(_errTimestampFormat));
  }

  final (amount, failureReason) = resolveZpHashAmountChecked(
    request.mode,
    request.paymentAmount,
  );

  if (failureReason == null) {
    return (amount, null);
  }

  return (
    null,
    switch (failureReason) {
      ZpAmountFailureReason.notANumber => const ZpFingerprintFailure(
        zpErrPaymentAmountNumber,
      ),
      ZpAmountFailureReason.notPositive => const ZpFingerprintFailure(
        zpErrPaymentAmountPositive,
      ),
      ZpAmountFailureReason.unresolvable => ZpFingerprintFailure(
        'invalid amount "${request.paymentAmount}" — expected a '
        'non-negative number with at most 2 decimal places',
      ),
    },
  );
}

/// Validates [request] without computing a fingerprint.
///
/// Returns `null` when [request] is valid.
ZpFingerprintFailure? validateZpFingerprintRequest(ZpFingerprintInput request) {
  final (_, failure) = _validate(request);
  return failure;
}

/// Creates the SHA3-512 fingerprint required by ZenPay Authorise.
///
/// Generate a fresh fingerprint, MUPID and timestamp for every plugin open.
/// Merchant credentials must remain server-side.
ZpFingerprintResult createZpFingerprint(ZpFingerprintInput request) {
  final (amount, failure) = _validate(request);

  if (failure != null) {
    return failure;
  }

  final pipe = [
    request.apiKey,
    request.username,
    request.password,
    request.mode.wireValue,
    amount!.value,
    request.merchantUniquePaymentId.value,
    request.timestamp.value,
  ].join(zpPipeDelimiter);

  return ZpFingerprintSuccess(createSha3_512(pipe));
}
