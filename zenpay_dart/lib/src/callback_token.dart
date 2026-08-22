/// HMAC-SHA3-512 signed callback URL token creation and verification for
/// stateless backends.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

import 'package:zenpay_dart/src/constants.dart';
import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/models/callback_token_models.dart';
import 'package:zenpay_dart/src/models/enums.dart';

Uint8List _keyBytes(Object secret) {
  final bytes = switch (secret) {
    final String value => Uint8List.fromList(utf8.encode(value)),
    final Uint8List value => value,
    _ => throw ArgumentError.value(
      secret,
      'secret',
      'must be a String or Uint8List',
    ),
  };

  if (bytes.length < ZpCore.minSecretBytes) {
    throw ArgumentError(
      'secret must be at least ${ZpCore.minSecretBytes} bytes long (provided ${bytes.length})',
    );
  }

  return bytes;
}

String _base64UrlEncode(List<int> bytes) => base64Url.encode(bytes).replaceAll(ZpCore.base64Padding, '');

Uint8List _base64UrlDecode(String value) {
  final padded = value.padRight(((value.length + 3) ~/ 4) * 4, ZpCore.base64Padding);

  return base64Url.decode(padded);
}

Uint8List _sign(String body, Uint8List key) {
  final mac = sha3_512.hmac.by(key).sign(utf8.encode(body));

  return Uint8List.fromList(mac.bytes.sublist(0, ZpCore.signatureBytes));
}

bool _isAmountShaped(Object? value) => value == null || value is String || value is num;

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
String createZpCallbackUrlToken(
  ZpCallbackUrlTokenPayload payload,
  Object secret, [
  ZpCallbackUrlTokenOptions options = const ZpCallbackUrlTokenOptions(),
]) {
  if (!isValidZpTimestamp(payload.timestamp.value)) {
    throw ArgumentError.value(
      payload.timestamp,
      'timestamp',
      'must match yyyy-MM-ddTHH:mm:ss',
    );
  }

  if (!_isAmountShaped(payload.paymentAmount)) {
    throw ArgumentError.value(
      payload.paymentAmount,
      'paymentAmount',
      'must be a String or a num',
    );
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
ZpCallbackUrlTokenResult verifyZpCallbackUrlToken(String token, Object secret) {
  final key = _keyBytes(secret);

  final signatureLength = _base64UrlEncode(Uint8List(ZpCore.signatureBytes)).length;

  if (token.length <= signatureLength) {
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.malformed,
    );
  }

  final body = token.substring(0, token.length - signatureLength);

  final providedSignature = token.substring(token.length - signatureLength);

  final Uint8List providedSignatureBytes;

  try {
    providedSignatureBytes = _base64UrlDecode(providedSignature);
  } on FormatException {
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.badSignature,
    );
  }

  if (!HashDigest(_sign(body, key)).isEqual(providedSignatureBytes)) {
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.badSignature,
    );
  }

  final data = _decodeBody(body);

  if (data == null) {
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.malformed,
    );
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
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.malformed,
    );
  }

  final mode = ZpPluginMode.tryFromWireValue(modeValue);

  if (mode == null) {
    return const ZpCallbackUrlTokenFailure(
      ZpCallbackUrlTokenFailureReason.malformed,
    );
  }

  if (expiresAt is int) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    if (now >= expiresAt) {
      return const ZpCallbackUrlTokenFailure(
        ZpCallbackUrlTokenFailureReason.expired,
      );
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
