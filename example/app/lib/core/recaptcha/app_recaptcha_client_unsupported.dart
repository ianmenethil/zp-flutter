/// Non-web [AppRecaptchaClient] resolution target.
///
/// reCAPTCHA is web-only in this demo — `app_config.dart`'s `recaptchaSiteKey`
/// is empty outside `kIsWeb`, so `main.dart` never actually calls
/// [fetchAppRecaptchaClient] here. This file exists only because Dart's
/// conditional import (`app_recaptcha_client_factory.dart`) needs a
/// compilable target for every platform; this one is unreachable at runtime.
library;

import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client.dart';

/// Always throws: reCAPTCHA has no implementation outside web.
Future<AppRecaptchaClient> fetchAppRecaptchaClient(String siteKey) => throw UnsupportedError('reCAPTCHA is web-only');
