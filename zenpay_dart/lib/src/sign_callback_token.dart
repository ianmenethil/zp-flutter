/// HMAC-SHA3-512 signed callback URL token creation and verification for
/// stateless backends.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:zenpay_dart/src/constants.dart';
import 'package:zenpay_dart/src/crypto_utils.dart';
import 'package:zenpay_dart/src/models/callback_token_data.dart';
import 'package:zenpay_dart/src/models/enums.dart';

Uint8List _keyBytes(Object secret) {
  final bytes = switch (secret) {
    final String value => Uint8List.fromList(utf8.encode(value)),
    final Uint8List value => value,
    _ => throw ArgumentError.value(secret, 'secret', 'must be a String or Uint8List'),
  };

  if (bytes.length < ZpCore.minSecretBytes) {
    throw ArgumentError('secret must be at least ${ZpCore.minSecretBytes} bytes long (provided ${bytes.length})');
  }

  return bytes;
}

String _base64UrlEncode(List<int> bytes) => base64Url.encode(bytes).replaceAll(ZpCore.base64Padding, '');

Uint8List _base64UrlDecode(String value) {
  final padded = value.padRight(((value.length + 3) ~/ 4) * 4, ZpCore.base64Padding);

  return base64Url.decode(padded);
}

Uint8List _sign(String body, Uint8List key) {
  final hmac = HMac(SHA3Digest(512), 72)..init(KeyParameter(key));
  final mac = hmac.process(Uint8List.fromList(utf8.encode(body)));

  return mac.sublist(0, ZpCore.signatureBytes);
}

// `is num` alone is not equivalent to TS's `z.number()`: NaN and Infinity are
// both `num` in Dart but are rejected by Zod, and they cannot be JSON-encoded,
// so without the finiteness check they slip past this guard and surface as an
// undocumented `JsonUnsupportedObjectError` from `jsonEncode` below.
bool _isAmountShaped(Object? value) => value == null || value is String || (value is num && value.isFinite);

Map<String, Object?>? _decodeBody(String body) {
  try {
    final decoded = jsonDecode(utf8.decode(_base64UrlDecode(body)));

    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Mints a signed, stateless callback URL token.
///
/// Sign with your own HMAC [secret] of at least 32 bytes, separate from the
/// ZenPay password. Embed the result in the launch `callbackUrl` as
/// `?t=<token>`.
///
/// Throws [ArgumentError] when [payload] is malformed (an invalid
/// [ZpCallbackUrlTokenPayload.timestamp], or a
/// [ZpCallbackUrlTokenPayload.paymentAmount] that is neither a `String` nor a
/// **finite** `num` — `NaN` and `Infinity` are rejected here, matching TS's
/// `z.number()`, rather than failing later during JSON encoding) or when
/// [secret] fails its
/// shape/length requirements — matching TS's `createZpCallbackUrlToken`,
/// which throws `TypeError`/`RangeError` for the identical cases
/// (`callbackurl-token.ts`). This is deliberately unlike `verifyZpCallback`,
/// which never throws and instead returns a Result type for every failure —
/// a token payload here is caller-constructed data you control, not
/// attacker-supplied wire input, so failing fast is appropriate.
String createZpCallbackUrlToken(ZpCallbackUrlTokenPayload payload, Object secret, [ZpCallbackUrlTokenOptions options = const ZpCallbackUrlTokenOptions()]) {
  if (!isValidZpTimestamp(payload.timestamp.value)) {
    throw ArgumentError.value(payload.timestamp, 'timestamp', 'must match yyyy-MM-ddTHH:mm:ss');
  }

  if (!_isAmountShaped(payload.paymentAmount)) {
    throw ArgumentError.value(payload.paymentAmount, 'paymentAmount', 'must be a String or a finite num');
  }

  final key = _keyBytes(secret);
  final issuedAt = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  final expiresInSeconds = options.expiresInSeconds;
  final expiresAt = expiresInSeconds == null ? null : issuedAt + expiresInSeconds;

  final wire = <String, Object?>{
    ...payload.extra,
    ZpCbTokenKeys.mode: payload.mode.wireValue,
    ZpCbTokenKeys.mupid: payload.merchantUniquePaymentId,
    ZpCbTokenKeys.timestamp: payload.timestamp,
    ZpCbTokenKeys.issuedAt: issuedAt,
    ZpCbTokenKeys.amount: ?payload.paymentAmount,
    ZpCbTokenKeys.expiresAt: ?expiresAt,
  };

  final body = _base64UrlEncode(utf8.encode(jsonEncode(wire)));

  return '$body${_base64UrlEncode(_sign(body, key))}';
}

/// Verifies and decodes a token minted by [createZpCallbackUrlToken].
///
/// Checks the HMAC-SHA3-512 signature and expiration before returning the
/// decoded payload. Use the same [secret] that was used to mint the token.
///
/// Throws [ArgumentError] when [secret] fails its shape/length requirements
/// — matching TS's `verifyZpCallbackUrlToken`, which throws `RangeError` for
/// the identical case (`callbackurl-token.ts`). A malformed or tampered
/// [token] itself does not throw: it returns [ZpCallbackUrlTokenFailure].
/// This split mirrors the create side — [secret] is caller-controlled
/// configuration (fail fast), while [token] is attacker-reachable wire input
/// (return a Result), the same distinction that makes `verifyZpCallback`
/// never throw at all for its wire input.
ZpCallbackUrlTokenResult verifyZpCallbackUrlToken(String token, Object secret) {
  final key = _keyBytes(secret);

  final signatureLength = _base64UrlEncode(Uint8List(ZpCore.signatureBytes)).length;

  if (token.length <= signatureLength) {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.malformed);
  }

  final body = token.substring(0, token.length - signatureLength);

  final providedSignature = token.substring(token.length - signatureLength);

  final Uint8List providedSignatureBytes;

  try {
    providedSignatureBytes = _base64UrlDecode(providedSignature);
  } on FormatException {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.badSignature);
  }

  if (!constantTimeBytesEqual(_sign(body, key), providedSignatureBytes)) {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.badSignature);
  }

  final data = _decodeBody(body);

  if (data == null) {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.malformed);
  }

  final modeValue = data[ZpCbTokenKeys.mode];
  final merchantUniquePaymentId = data[ZpCbTokenKeys.mupid];
  final timestamp = data[ZpCbTokenKeys.timestamp];
  final paymentAmount = data[ZpCbTokenKeys.amount];
  final issuedAt = data[ZpCbTokenKeys.issuedAt];
  final expiresAt = data[ZpCbTokenKeys.expiresAt];

  if (modeValue is! int ||
      merchantUniquePaymentId is! String ||
      timestamp is! String ||
      !isValidZpTimestamp(timestamp) ||
      !_isAmountShaped(paymentAmount) ||
      issuedAt is! int ||
      (expiresAt != null && expiresAt is! int)) {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.malformed);
  }

  final mode = ZpPluginMode.tryFromWireValue(modeValue);

  if (mode == null) {
    return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.malformed);
  }

  if (expiresAt is int) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    if (now >= expiresAt) {
      return const ZpCallbackUrlTokenFailure(ZpCallbackUrlTokenFailureReason.expired);
    }
  }

  final extra = Map<String, Object?>.from(data)
    ..remove(ZpCbTokenKeys.mode)
    ..remove(ZpCbTokenKeys.mupid)
    ..remove(ZpCbTokenKeys.timestamp)
    ..remove(ZpCbTokenKeys.amount)
    ..remove(ZpCbTokenKeys.issuedAt)
    ..remove(ZpCbTokenKeys.expiresAt);

  return ZpCallbackUrlTokenVerified(
    ZpCallbackUrlTokenPayload(
      mode: mode,
      merchantUniquePaymentId: ZpMupid(merchantUniquePaymentId),
      timestamp: ZpTimestamp(timestamp),
      paymentAmount: paymentAmount,
      extra: extra,
    ),
  );
}
