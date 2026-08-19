/// Purpose-scoped signing keys, all derived from the one configured root
/// secret (`AppConfig.tokenSecret`, env `TOKEN_SECRET`).
///
/// `checkoutToken` and `zenpay_dart`'s own `ZpCallbackUrlToken` (`t`) each
/// sign with a different key here — real cryptographic domain separation,
/// not just a `scope` claim checked after decoding. A token minted for one
/// purpose fails signature verification against another purpose's key
/// before its claims are ever read. Keeps configuration to one secret; see
/// `signed_token.dart`'s [deriveTokenKey] for the derivation itself
/// (HMAC-SHA3-512 over a fixed purpose label).
///
/// Rotating `TOKEN_SECRET`, or changing either purpose label below, changes
/// every derived key and invalidates every outstanding `checkoutToken` and
/// `t` token — by design, not a bug to guard against.
library;

import 'dart:typed_data';

import 'config.dart' show AppConfig;
import 'signed_token.dart' show deriveTokenKey;

const _checkoutTokenPurpose = 'checkout-token-v1';
const _callbackTokenPurpose = 'callback-token-v1';

/// Signing key for `checkoutToken` (`checkout_token.dart`).
Uint8List checkoutTokenKey(AppConfig config) =>
    deriveTokenKey(config.tokenSecret, _checkoutTokenPurpose);

/// Signing key for `zenpay_dart`'s `ZpCallbackUrlToken` (`t`) — passed as
/// the `Object secret` argument the SDK already accepts; the SDK itself is
/// unmodified.
Uint8List callbackTokenKey(AppConfig config) =>
    deriveTokenKey(config.tokenSecret, _callbackTokenPurpose);
