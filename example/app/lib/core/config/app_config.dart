/// Demo config, supplied by `--dart-define-from-file=.env` (see `.env.example`).
///
/// Defaults mirror `.env.example` so the demo runs unconfigured against a local
/// backend; anything real comes from `.env`.
library;

import 'package:flutter/foundation.dart' show kIsWeb;

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
