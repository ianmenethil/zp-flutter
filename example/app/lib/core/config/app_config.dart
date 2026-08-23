/// Demo config, supplied by `--dart-define-from-file=.env` (see `.env.example`).
///
/// Defaults mirror `.env.example` so the demo runs unconfigured against a local
/// backend; anything real comes from `.env`.
library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client.dart';

/// reCAPTCHA Enterprise site key for the current platform.
final String recaptchaSiteKey = () {
  if (kIsWeb) return '6LcMto4tAAAAABbToTnAcvrbyNrV4iltvsIZwHaX';
  if (defaultTargetPlatform == TargetPlatform.android) return const String.fromEnvironment('RECAPTCHA_ANDROID_KEY', defaultValue: 'YOUR_ANDROID_KEY');
  if (defaultTargetPlatform == TargetPlatform.iOS) return const String.fromEnvironment('RECAPTCHA_IOS_KEY', defaultValue: 'YOUR_IOS_KEY');
  return '';
}();

/// The reCAPTCHA Enterprise client, set once `main()`'s
/// `fetchAppRecaptchaClient` call resolves. Null until then, and permanently
/// null when [recaptchaSiteKey] is empty, since reCAPTCHA is never
/// initialized at all.
AppRecaptchaClient? recaptchaClient;

const _backendBaseUrlEnvKey = 'BACKEND_BASE_URL';
const _defaultBackendBaseUrl = 'http://localhost:7000';

const _appReturnUriWebEnvKey = 'APP_RETURN_URI_WEB';
const _defaultAppReturnUriWeb = 'https://localhost:3000/';

const _appReturnUriMobileEnvKey = 'APP_RETURN_URI_MOBILE';
const _defaultAppReturnUriMobile = 'https://payments.example.com/zenpay/app-return';

const _allowedCheckoutHostsEnvKey = 'ALLOWED_CHECKOUT_HOSTS';
const _defaultAllowedCheckoutHosts = 'pay.sandbox.travelpay.com.au';

/// Example backend base URL.
final Uri backendBaseUrl = Uri.parse(
  const String.fromEnvironment(
    _backendBaseUrlEnvKey,
    defaultValue: _defaultBackendBaseUrl,
  ),
);

/// Return URI the SDK expects. Must be `https` and match the backend's exactly.
///
/// Platform-dependent, mirroring the backend: web checkouts return to the app's
/// own origin, mobile ones to the App Link on the public host.
final Uri appReturnUri = Uri.parse(
  kIsWeb
      ? const String.fromEnvironment(
          _appReturnUriWebEnvKey,
          defaultValue: _defaultAppReturnUriWeb,
        )
      : const String.fromEnvironment(
          _appReturnUriMobileEnvKey,
          defaultValue: _defaultAppReturnUriMobile,
        ),
);

/// Hosts a checkout URL may point at.
final Set<String> allowedCheckoutHosts = const String.fromEnvironment(
  _allowedCheckoutHostsEnvKey,
  defaultValue: _defaultAllowedCheckoutHosts,
).split(',').toSet();
