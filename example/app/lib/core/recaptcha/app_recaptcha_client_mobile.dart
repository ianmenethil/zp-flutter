/// Mobile [AppRecaptchaClient]: delegates to `recaptcha_enterprise_flutter`'s
/// native Android/iOS SDKs.
library;

import 'package:recaptcha_enterprise_flutter/recaptcha.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_action.dart';
import 'package:recaptcha_enterprise_flutter/recaptcha_client.dart';
import 'package:zenpay_example_app/core/recaptcha/app_recaptcha_client.dart';

/// Fetches the mobile [AppRecaptchaClient] for [siteKey].
Future<AppRecaptchaClient> fetchAppRecaptchaClient(String siteKey) async => _MobileAppRecaptchaClient(await Recaptcha.fetchClient(siteKey));

final class _MobileAppRecaptchaClient implements AppRecaptchaClient {
  _MobileAppRecaptchaClient(this._client);
  final RecaptchaClient _client;

  @override
  Future<String> execute(String action) => _client.execute(RecaptchaAction.custom(action));
}
