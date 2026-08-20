/// Callback signature verification and timing-safe comparison.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';
import 'package:zenpay_dart/zenpay_dart.dart';

import 'package:zenpay_example_backend/src/config.dart' show ZenPayCredentials;
import 'package:zenpay_example_backend/src/models.dart' show CheckoutAttempt;

/// Compares [a] and [b] in constant time via SHA-256 digest equality.
bool constantTimeEqual(String a, String b) => HashDigest(Uint8List.fromList(utf8.encode(a))).isEqual(utf8.encode(b));

/// Callback fields this backend derives from ZenPay's raw response once
/// `zenpay_dart` has verified authenticity.
///
/// `verifyZpCallback` itself returns no data — mirrors `@ianmenethil/zp-hcp`'s
/// TypeScript `verifyZpCallback`, which is pass/fail only. Reading and
/// interpreting the response is every integrator's own job, this backend
/// included; [rawPayload] carries the whole thing, unfiltered.
class CallbackFields {
  /// Creates a [CallbackFields].
  const CallbackFields({
    required this.reference,
    required this.statusCode,
    required this.rawPayload,
    this.failureCode,
    this.failureReason,
  });

  /// Mode-specific payment, preauthorization, or token reference.
  final String reference;

  /// Raw ZenPay payment status wire code.
  final int statusCode;

  /// Failure code, if the payment failed.
  final String? failureCode;

  /// Failure reason, if the payment failed.
  final String? failureReason;

  /// The entire callback body ZenPay posted — `{response, validationCode}`
  /// — unfiltered.
  final Map<String, Object?> rawPayload;
}

/// Result of authenticating an incoming ZenPay webhook body.
class CallbackVerification {
  /// Creates a successful verification result carrying [fields].
  const CallbackVerification.ok(this.fields) : reason = null;

  /// Creates a rejected verification result with the given [reason].
  const CallbackVerification.rejected(this.reason) : fields = null;

  /// Extracted callback fields, present only when verification succeeded.
  final CallbackFields? fields;

  /// `"malformed"` (payload doesn't match the attempt's mode) or
  /// `"rejected"` (SHA3-512 ValidationCode check failed).
  final String? reason;

  /// Whether verification succeeded.
  bool get ok => fields != null;
}

/// Reads the mode-specific status code out of [response].
///
/// Mirrors `ZpPluginMode.callbackReferenceField`'s per-mode field lookup, but
/// for status. Tokenise (mode 1) carries no status field in ZenPay's response
/// at all — reaching a verified callback for it already proves success, so
/// this reports it as such.
int _statusCodeFrom(int mode, Map<String, Object?> response) {
  if (mode == 1) return ZpPaymentStatus.successful.wireValue;
  final field = mode == 3 ? 'preauthStatus' : 'paymentStatus';
  final value = response[field];
  return value is num ? value.toInt() : ZpPaymentStatus.pending.wireValue;
}

/// Verifies an incoming ZenPay webhook [payload] against a stored [attempt]
/// via `package:zenpay_dart`'s `verifyZpCallback` — the sole authoritative
/// proof that a callback was minted by ZenPay.
///
/// `verifyZpCallback` proves authenticity only and returns no data; this
/// function derives the fields this backend needs directly from [payload],
/// which it already holds in full.
CallbackVerification verifyCallback(
  Map<String, Object?> payload,
  CheckoutAttempt attempt,
  ZenPayCredentials credentials,
) {
  final mode = ZpPluginMode.fromWireValue(attempt.mode);
  final result = verifyZpCallback(
    mode,
    payload,
    ZpVerifyCallbackContext(
      apiKey: credentials.apiKey,
      username: credentials.username,
      password: credentials.password,
      paymentAmount: attempt.amount ?? 0,
      merchantUniquePaymentId: ZpMupid(attempt.merchantUniquePaymentId),
    ),
  );

  switch (result) {
    case ZpCallbackMalformed():
      return const CallbackVerification.rejected('malformed');
    case ZpCallbackRejected():
      return const CallbackVerification.rejected('rejected');
    case ZpCallbackVerified():
      final response = payload['response']! as Map<String, Object?>;
      return CallbackVerification.ok(
        CallbackFields(
          reference: response[mode.callbackReferenceField]! as String,
          statusCode: _statusCodeFrom(attempt.mode, response),
          failureCode: response['failureCode'] as String?,
          failureReason: response['failureReason'] as String?,
          rawPayload: payload,
        ),
      );
  }
}
