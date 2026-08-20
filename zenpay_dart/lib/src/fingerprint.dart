/// Outgoing ZenPay HCP Authorise fingerprint generation.
library;

import 'package:zenpay_dart/src/constants.dart';
import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/models/fingerprint_models.dart';

(ZpCents?, ZpFingerprintFailure?) _validate(ZpFingerprintInput request) {
  if (request.apiKey.length < ZpCore.minCredentialLength) {
    return (null, const ZpFingerprintFailure(ZpErrors.apiKeyLength));
  }

  if (request.username.length < ZpCore.minCredentialLength) {
    return (null, const ZpFingerprintFailure(ZpErrors.usernameLength));
  }

  if (request.password.length < ZpCore.minCredentialLength) {
    return (null, const ZpFingerprintFailure(ZpErrors.passwordLength));
  }

  if (request.merchantUniquePaymentId.value.length < ZpCore.minCredentialLength) {
    return (null, const ZpFingerprintFailure(ZpErrors.mupidLength));
  }

  if (!isValidZpTimestamp(request.timestamp.value)) {
    return (null, const ZpFingerprintFailure(ZpErrors.timestampFormat));
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
        ZpErrors.paymentAmountNumber,
      ),
      ZpAmountFailureReason.notPositive => const ZpFingerprintFailure(
        ZpErrors.paymentAmountPositive,
      ),
      ZpAmountFailureReason.unresolvable => ZpFingerprintFailure(
        ZpErrors.paymentAmountUnresolvable(request.paymentAmount),
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
  ].join(ZpCore.pipeDelimiter);

  return ZpFingerprintSuccess(createSha3_512(pipe));
}
