/// Incoming HCP callback verification.
///
/// Mirrors `@ianmenethil/zp-hcp`'s TypeScript `verifyZpCallback`: this proves
/// callback *authenticity* only and returns no data — you already have the
/// full callback body (you passed it in), so read whatever fields you need
/// from it directly, e.g. `payload['response']['paymentStatus']` against
/// [ZpPaymentStatus] to check *success* separately. [ZpPluginMode] exposes
/// [ZpPluginMode.callbackReferenceField] so you don't have to hardcode which
/// field carries the reference for a given mode.
library;

import 'package:zenpay_dart/src/constants.dart';
import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/models/callback_models.dart';
import 'package:zenpay_dart/src/models/enums.dart';

typedef _CallbackShape = ({
  Map<String, Object?> response,
  String reference,
  String validationCode,
});

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is! Map) return null;

  final result = <String, Object?>{};

  for (final MapEntry(:key, :value) in value.entries) {
    if (key is! String) return null;
    result[key] = value;
  }

  return result;
}

String? _string(
  Map<String, Object?> data,
  String key, {
  String path = 'response',
}) => switch (data[key]) {
  null => null,
  final String value => value,
  _ => throw FormatException('$path.$key must be a string'),
};

_CallbackShape _parseCallbackShape(
  ZpPluginMode mode,
  Map<String, Object?> body,
) {
  final response = _asObjectMap(body['response']);
  final validationCode = body['validationCode'];

  if (response == null || validationCode is! String) {
    throw const FormatException(ZpErrors.malformedBody);
  }

  final referenceField = mode.callbackReferenceField;
  final reference = response[referenceField];

  if (reference is! String || reference.trim().isEmpty) {
    throw FormatException('response.$referenceField must not be empty');
  }

  if (!ZpPatterns.validationCode.hasMatch(validationCode)) {
    throw const FormatException(ZpErrors.validationCodeHex);
  }

  return (
    response: response,
    reference: reference,
    validationCode: validationCode,
  );
}

(ZpCents?, ZpCallbackRejected?) _validateCallbackContext(
  ZpPluginMode mode,
  ZpVerifyCallbackContext context,
) {
  if (context.apiKey.length < ZpCore.minCredentialLength ||
      context.username.length < ZpCore.minCredentialLength ||
      context.password.length < ZpCore.minCredentialLength ||
      context.merchantUniquePaymentId.value.length < ZpCore.minCredentialLength) {
    return (null, const ZpCallbackRejected(ZpErrors.credentialLength));
  }

  final (amount, failureReason) = resolveZpHashAmountChecked(
    mode,
    context.paymentAmount,
  );

  if (failureReason == null) {
    return (amount, null);
  }

  return (
    null,
    switch (failureReason) {
      ZpAmountFailureReason.notANumber => const ZpCallbackRejected(
        ZpErrors.paymentAmountNumber,
      ),
      ZpAmountFailureReason.notPositive => const ZpCallbackRejected(
        ZpErrors.paymentAmountPositive,
      ),
      ZpAmountFailureReason.unresolvable => ZpCallbackRejected(
        ZpErrors.paymentAmountUnresolvable(context.paymentAmount),
      ),
    },
  );
}

bool _verifyCallbackHash({
  required ZpPluginMode mode,
  required ZpVerifyCallbackContext context,
  required ZpCents amount,
  required String reference,
  required String validationCode,
}) {
  final value = [
    context.apiKey,
    context.username,
    context.password,
    mode.wireValue.toString(),
    amount.value,
    context.merchantUniquePaymentId.value,
    reference,
  ].join(ZpCore.pipeDelimiter);

  return constantTimeHexEqual(createSha3_512(value), validationCode);
}

/// Validates the callback body's structural shape for [mode].
///
/// The body must contain a `response` object, a non-empty mode-specific
/// reference, and a 128-character hexadecimal `validationCode`.
///
/// Returns `null` when [body] is structurally valid. This does not verify
/// callback authenticity.
ZpCallbackMalformed? validateZpCallbackBody(
  ZpPluginMode mode,
  Map<String, Object?> body,
) {
  try {
    _parseCallbackShape(mode, body);
    return null;
  } on FormatException catch (error) {
    return ZpCallbackMalformed(error.message);
  }
}

/// Verifies the authenticity of an incoming HCP callback.
///
/// Supports payment (mode 0/2), preauthorization (mode 3), and tokenisation
/// (mode 1) callbacks by recomputing the SHA3-512 validation hash and
/// comparing it in constant time with `body.validationCode`.
///
/// Recover [mode] from your own launch state. Never infer it from [body].
///
/// Never throws for malformed callback data.
ZpCallbackResult verifyZpCallback(
  ZpPluginMode mode,
  Map<String, Object?> body,
  ZpVerifyCallbackContext context,
) {
  try {
    final (:response, :reference, :validationCode) = _parseCallbackShape(
      mode,
      body,
    );

    final (amount, contextError) = _validateCallbackContext(mode, context);

    if (contextError != null) {
      return contextError;
    }

    if (!_verifyCallbackHash(
      mode: mode,
      context: context,
      amount: amount!,
      reference: reference,
      validationCode: validationCode,
    )) {
      return const ZpCallbackRejected(ZpErrors.validationCodeMismatch);
    }

    final echoedMupid = _string(response, 'merchantUniquePaymentId');

    if (echoedMupid != null && echoedMupid.isNotEmpty && echoedMupid != context.merchantUniquePaymentId.value) {
      return const ZpCallbackRejected(ZpErrors.mupidMismatch);
    }

    return const ZpCallbackVerified();
  } on FormatException catch (error) {
    return ZpCallbackMalformed(error.message);
  }
}
