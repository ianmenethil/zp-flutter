/// Shared HMAC-SHA3-512 signed-token codec underlying the example backend's
/// local token type (`checkout_token.dart`), plus [deriveTokenKey] — the
/// domain-separation primitive `token_keys.dart` uses so `checkoutToken` and
/// `zenpay_dart`'s own `ZpCallbackUrlToken` (`t`), despite sharing one
/// configured root secret, each sign with a cryptographically distinct
/// derived key. A token minted for one purpose fails signature verification
/// against another purpose's key — this holds before any claim is even
/// decoded, not just after a `scope` check. See `token_keys.dart` for where
/// each purpose's key is actually used; `checkout_token.dart`'s `scope`
/// claim is defense in depth on top of key separation, not a substitute
/// for it.
///
/// Deliberately separate from `zenpay_dart`'s `ZpCallbackUrlToken` codec,
/// which stays scoped to one attempt's `merchantUniquePaymentId` and is
/// never modified here — see that file's doc comment. This codec only
/// handles the generic sign/verify envelope; callers own their own claim
/// shape and expiry check.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const _minSecretBytes = 32;
const _signatureBytes = 16;
const _padding = '=';

/// Result of [decodeSignedToken].
sealed class SignedTokenDecodeResult {
  const SignedTokenDecodeResult();
}

/// The token's signature verified and its body decoded to a claims map.
final class SignedTokenDecoded extends SignedTokenDecodeResult {
  /// Creates a [SignedTokenDecoded] wrapping the decoded [claims].
  const SignedTokenDecoded(this.claims);

  /// The decoded claims map. Callers still own validating its shape.
  final Map<String, Object?> claims;
}

/// The token was too short, not valid base64url, or not a JSON object.
final class SignedTokenMalformed extends SignedTokenDecodeResult {
  /// Creates a [SignedTokenMalformed].
  const SignedTokenMalformed();
}

/// The signature does not match the supplied secret.
final class SignedTokenBadSignature extends SignedTokenDecodeResult {
  /// Creates a [SignedTokenBadSignature].
  const SignedTokenBadSignature();
}

Uint8List _keyBytes(Object secret) {
  final bytes = switch (secret) {
    final String value => Uint8List.fromList(utf8.encode(value)),
    final Uint8List value => value,
    _ => throw ArgumentError.value(secret, 'secret', 'must be a String or Uint8List'),
  };
  if (bytes.length < _minSecretBytes) {
    throw RangeError('secret must be at least $_minSecretBytes bytes (got ${bytes.length})');
  }
  return bytes;
}

/// Derives a purpose-scoped signing key from [rootSecret] via
/// HMAC-SHA3-512 over [purpose] — the same primitive already used to sign
/// every token here, applied once more as an HKDF-style domain separator.
/// [rootSecret] must be at least 32 bytes, same as any token secret.
Uint8List deriveTokenKey(Object rootSecret, String purpose) {
  final rootBytes = _keyBytes(rootSecret);
  final hmac = HMac(SHA3Digest(512), 72)..init(KeyParameter(rootBytes));
  return hmac.process(Uint8List.fromList(utf8.encode(purpose)));
}

/// Compares two byte sequences in constant time.
bool _constantTimeBytesEqual(List<int> a, List<int> b) {
  var mismatch = a.length ^ b.length;
  for (var i = 0; i < a.length; i++) {
    mismatch |= a[i] ^ (i < b.length ? b[i] : 0);
  }
  return mismatch == 0;
}

String _base64UrlEncode(List<int> bytes) => base64Url.encode(bytes).replaceAll(_padding, '');

Uint8List _base64UrlDecode(String value) {
  final padded = value.padRight(((value.length + 3) ~/ 4) * 4, _padding);
  return base64Url.decode(padded);
}

Uint8List _sign(String body, Uint8List key) {
  final hmac = HMac(SHA3Digest(512), 72)..init(KeyParameter(key));
  final mac = hmac.process(Uint8List.fromList(utf8.encode(body)));
  return mac.sublist(0, _signatureBytes);
}

/// Encodes [claims] as a compact HMAC-SHA3-512 signed token, using [secret]
/// (a `String` or `Uint8List` of at least 32 bytes — typically a
/// [deriveTokenKey] result).
String encodeSignedToken(Map<String, Object?> claims, Object secret) {
  final key = _keyBytes(secret);
  final body = _base64UrlEncode(utf8.encode(jsonEncode(claims)));
  return '$body${_base64UrlEncode(_sign(body, key))}';
}

/// Decodes and verifies a token minted by [encodeSignedToken] against
/// [secret]. Never logs or echoes the raw [token] — callers must not either.
SignedTokenDecodeResult decodeSignedToken(String token, Object secret) {
  final key = _keyBytes(secret);
  final signatureLength = _base64UrlEncode(Uint8List(_signatureBytes)).length;

  if (token.length <= signatureLength) {
    return const SignedTokenMalformed();
  }

  final body = token.substring(0, token.length - signatureLength);
  final providedSignature = token.substring(token.length - signatureLength);

  final Uint8List providedSignatureBytes;
  try {
    providedSignatureBytes = _base64UrlDecode(providedSignature);
  } on FormatException {
    return const SignedTokenBadSignature();
  }

  if (!_constantTimeBytesEqual(_sign(body, key), providedSignatureBytes)) {
    return const SignedTokenBadSignature();
  }

  try {
    final decoded = jsonDecode(utf8.decode(_base64UrlDecode(body)));
    return decoded is Map<String, Object?> ? SignedTokenDecoded(decoded) : const SignedTokenMalformed();
  } on FormatException {
    return const SignedTokenMalformed();
  }
}
