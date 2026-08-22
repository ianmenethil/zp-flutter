/// Runtime configuration for the example backend.
///
/// Loads settings from a `.env` file overlaid with process environment
/// variables (process environment variables always take precedence).
library;

import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// ZenPay API credentials used for fingerprinting and callback verification.
///
/// Must never be logged or serialized to client responses.
class ZenPayCredentials {
  /// Creates a [ZenPayCredentials].
  const ZenPayCredentials({
    required this.merchantCode,
    required this.apiKey,
    required this.username,
    required this.password,
  });

  /// ZenPay merchant identifier.
  final String merchantCode;

  /// ZenPay API key, hashed into the fingerprint and callback signature.
  final String apiKey;

  /// Merchant username, hashed into the fingerprint and callback signature.
  final String username;

  /// Merchant password, hashed into the fingerprint and callback signature.
  final String password;
}

/// ZenPay Hosted Payment Page (HCP) endpoint configuration and allowlist.
class ZenPayConfig {
  /// Creates a [ZenPayConfig].
  const ZenPayConfig({
    required this.hppEndpointUrl,
    required this.allowedCheckoutHosts,
    required this.credentials,
  });

  /// The full HCP Authorise endpoint URL, including its `/Online/vN` path.
  final Uri hppEndpointUrl;

  /// Allowlist of permitted hostnames for generated checkout launch URLs.
  final Set<String> allowedCheckoutHosts;

  /// ZenPay merchant credentials.
  final ZenPayCredentials credentials;
}

/// Immutable runtime configuration for the example backend.
class AppConfig {
  /// Creates an [AppConfig].
  const AppConfig({
    required this.port,
    required this.publicBaseUrl,
    required this.allowedAppOrigin,
    required this.appReturnUriWeb,
    required this.checkoutStatusTtlMinutes,
    required this.tokenSecret,
    required this.checkoutTokenTtlSeconds,
    required this.checkoutRateLimitPerMinute,
    required this.firebaseProjectNumber,
    required this.firebaseServiceAccountJson,
    required this.recaptchaSiteKeyWeb,
    required this.recaptchaSiteKeyAndroid,
    required this.recaptchaSiteKeyIos,
    required this.zenPay,
  });

  /// TCP port this backend listens on.
  final int port;

  /// Canonical public base URL this backend is reachable at — used to build
  /// callback and return URLs.
  final Uri publicBaseUrl;

  /// Permitted origin for CORS.
  final String allowedAppOrigin;

  /// Browser return URI for web clients after payment completion.
  final Uri appReturnUriWeb;

  /// In-memory storage time-to-live (minutes) for checkout attempts. Also
  /// used as the lifetime of a signed return/status token.
  final int checkoutStatusTtlMinutes;

  /// Root secret every token type derives its signing key from — the SDK's
  /// return/status (`t`) token and `checkoutToken` (see
  /// `lib/src/token_keys.dart`). Separate from the ZenPay password.
  ///
  /// Rotating this value, or changing a derivation purpose label in
  /// `token_keys.dart`, invalidates every outstanding `checkoutToken` and
  /// `t` token immediately — there is no versioning or grace period. That's
  /// acceptable here: both are short-lived and this backend holds no other
  /// state that depends on them surviving a restart.
  final String tokenSecret;

  /// Lifetime (seconds) of a `POST /api/v1/checkout/token` capability —
  /// deliberately much shorter than [checkoutStatusTtlMinutes]: it only
  /// needs to survive the gap before the client calls `/checkout/exchange`.
  final int checkoutTokenTtlSeconds;

  /// Per-IP requests-per-minute allowed on the checkout-creation endpoints
  /// (`/checkout/token`, `/checkout/exchange`).
  final int checkoutRateLimitPerMinute;

  /// Firebase project number for App Check token verification.
  /// Empty string disables enforcement (local dev without Firebase).
  final String firebaseProjectNumber;

  /// Raw JSON string or file path to GCP Service Account credentials.
  final String firebaseServiceAccountJson;

  /// reCAPTCHA Enterprise site key for the web client.
  final String recaptchaSiteKeyWeb;

  /// reCAPTCHA Enterprise site key for the Android client.
  final String recaptchaSiteKeyAndroid;

  /// reCAPTCHA Enterprise site key for the iOS client.
  final String recaptchaSiteKeyIos;

  /// ZenPay endpoint configuration and credentials.
  final ZenPayConfig zenPay;
}

String? _read(DotEnv file, String key) {
  final real = Platform.environment[key];
  if (real != null && real.isNotEmpty) return real;
  return file.isDefined(key) ? file[key] : null;
}

int _numberOr(String? raw, int fallback) {
  final n = raw == null ? null : num.tryParse(raw);
  return (n == null || n == 0) ? fallback : n.toInt();
}

/// Loads [AppConfig] from `.env` (if present), overlaid by real process
/// environment variables.
AppConfig loadConfig() {
  final file = DotEnv(quiet: true)..load();
  String value(String key, String fallback) => _read(file, key) ?? fallback;

  final hosts = value(
    'ZENPAY_ALLOWED_CHECKOUT_HOSTS',
    'pay.sandbox.travelpay.com.au',
  ).split(',').map((h) => h.trim().toLowerCase()).where((h) => h.isNotEmpty).toSet();

  return AppConfig(
    port: _numberOr(_read(file, 'PORT'), 7000),
    publicBaseUrl: Uri.parse(value('PUBLIC_BASE_URL', 'http://localhost:7000')),
    allowedAppOrigin: value('ALLOWED_APP_ORIGIN', 'http://localhost:3000'),
    appReturnUriWeb: Uri.parse(
      value('APP_RETURN_URI_WEB', 'https://localhost:3000/'),
    ),
    checkoutStatusTtlMinutes: _numberOr(
      _read(file, 'CHECKOUT_STATUS_TTL_MINUTES'),
      60,
    ),
    tokenSecret: value('TOKEN_SECRET', ''),
    checkoutTokenTtlSeconds: _numberOr(
      _read(file, 'CHECKOUT_TOKEN_TTL_SECONDS'),
      300,
    ),
    checkoutRateLimitPerMinute: _numberOr(
      _read(file, 'CHECKOUT_RATE_LIMIT_PER_MINUTE'),
      20,
    ),
    firebaseProjectNumber: value('FIREBASE_PROJECT_NUMBER', ''),
    firebaseServiceAccountJson: value('FIREBASE_SERVICE_ACCOUNT_JSON', ''),
    recaptchaSiteKeyWeb: value('RECAPTCHA_SITE_KEY_WEB', 'YOUR_SITE_KEY_WEB'),
    recaptchaSiteKeyAndroid: value('RECAPTCHA_SITE_KEY_ANDROID', 'YOUR_SITE_KEY_ANDROID'),
    recaptchaSiteKeyIos: value('RECAPTCHA_SITE_KEY_IOS', 'YOUR_SITE_KEY_IOS'),
    zenPay: ZenPayConfig(
      hppEndpointUrl: Uri.parse(
        value(
          'ZENPAY_HPP_ENDPOINT_URL',
          'https://pay.sandbox.travelpay.com.au/Online/v5',
        ),
      ),
      allowedCheckoutHosts: hosts,
      credentials: ZenPayCredentials(
        merchantCode: value('ZENPAY_MERCHANT_CODE', ''),
        apiKey: value('ZENPAY_API_KEY', ''),
        username: value('ZENPAY_USERNAME', ''),
        password: value('ZENPAY_PASSWORD', ''),
      ),
    ),
  );
}

/// Missing environment variables required for session creation.
List<String> sessionConfigurationErrors(AppConfig config) => [
  if (config.zenPay.credentials.merchantCode.isEmpty) 'ZENPAY_MERCHANT_CODE',
  if (config.zenPay.credentials.apiKey.isEmpty) 'ZENPAY_API_KEY',
  if (config.zenPay.credentials.username.isEmpty) 'ZENPAY_USERNAME',
  if (config.zenPay.credentials.password.isEmpty) 'ZENPAY_PASSWORD',
  if (config.tokenSecret.length < 32) 'TOKEN_SECRET',
];

/// Missing environment variables required for callback verification.
List<String> callbackConfigurationErrors(AppConfig config) => [
  if (config.zenPay.credentials.apiKey.isEmpty) 'ZENPAY_API_KEY',
  if (config.zenPay.credentials.username.isEmpty) 'ZENPAY_USERNAME',
  if (config.zenPay.credentials.password.isEmpty) 'ZENPAY_PASSWORD',
];
