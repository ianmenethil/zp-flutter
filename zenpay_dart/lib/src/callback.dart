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

import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/enums.dart';

final _validationCodePattern = RegExp(r'^[0-9a-f]{128}$');

const _errValidationCodeHex = 'validationCode must be a 128-character hex string';

const _errCredentialLength =
    'apiKey, username, password, and merchantUniquePaymentId must each '
    'be at least 5 characters';

const _errPaymentAmountInvalid = 'paymentAmount is invalid';

const _errValidationCodeMismatch = 'validationCode does not match the computed hash';

const _errMupidMismatch = 'response.merchantUniquePaymentId does not match the launched attempt';

const _errMalformedBody = 'body must contain a response object and a validationCode string';

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

/// Result of [verifyZpCallback].
///
/// Exhaustively pattern-match with a `switch` over [ZpCallbackVerified],
/// [ZpCallbackMalformed], and [ZpCallbackRejected].
sealed class ZpCallbackResult {
  /// Base constructor for callback verification results.
  const ZpCallbackResult();
}

/// An authentic callback — proves the callback was minted by ZenPay, nothing
/// more. Carries no data: you already hold the full callback body you passed
/// to [verifyZpCallback], so read whatever fields you need from it directly.
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
    throw const FormatException(_errMalformedBody);
  }

  final referenceField = mode.callbackReferenceField;
  final reference = response[referenceField];

  if (reference is! String || reference.trim().isEmpty) {
    throw FormatException('response.$referenceField must not be empty');
  }

  if (!_validationCodePattern.hasMatch(validationCode)) {
    throw const FormatException(_errValidationCodeHex);
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
  if (context.apiKey.length < zpMinCredentialLength ||
      context.username.length < zpMinCredentialLength ||
      context.password.length < zpMinCredentialLength ||
      context.merchantUniquePaymentId.value.length < zpMinCredentialLength) {
    return (null, const ZpCallbackRejected(_errCredentialLength));
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
        zpErrPaymentAmountNumber,
      ),
      ZpAmountFailureReason.notPositive => const ZpCallbackRejected(
        zpErrPaymentAmountPositive,
      ),
      ZpAmountFailureReason.unresolvable => const ZpCallbackRejected(
        _errPaymentAmountInvalid,
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
  ].join(zpPipeDelimiter);

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
      return const ZpCallbackRejected(_errValidationCodeMismatch);
    }

    final echoedMupid = _string(response, 'merchantUniquePaymentId');

    if (echoedMupid != null && echoedMupid.isNotEmpty && echoedMupid != context.merchantUniquePaymentId.value) {
      return const ZpCallbackRejected(_errMupidMismatch);
    }

    return const ZpCallbackVerified();
  } on FormatException catch (error) {
    return ZpCallbackMalformed(error.message);
  }
}
