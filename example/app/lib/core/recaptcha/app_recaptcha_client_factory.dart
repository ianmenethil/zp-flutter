/// Platform resolver for [AppRecaptchaClient].
///
/// Conditionally imports the platform-appropriate implementation: Web (via
/// `dart.library.js_interop`) or Mobile (`app_recaptcha_client_mobile.dart`),
/// mirroring `zenpay_flutter`'s `presenter_factory.dart`.
library;

import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client.dart';
import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client_mobile.dart' if (dart.library.js_interop) 'app_recaptcha_client_web.dart' as impl;

/// Fetches a platform-specific [AppRecaptchaClient] for [siteKey].
Future<AppRecaptchaClient> fetchAppRecaptchaClient(String siteKey) => impl.fetchAppRecaptchaClient(siteKey);
