/// Platform-agnostic reCAPTCHA Enterprise client contract for this demo.
///
/// `package:recaptcha_enterprise_flutter` only implements Android and iOS
/// (see its `pubspec.yaml` — `plugin.platforms` lists no `web:` entry), so
/// this app defines its own minimal client shape and resolves a
/// platform-specific implementation via `app_recaptcha_client_factory.dart`,
/// mirroring `zenpay_flutter`'s `CheckoutPresenter` resolution pattern.
library;

/// A reCAPTCHA Enterprise client capable of minting an assessment token.
abstract class AppRecaptchaClient {
  /// Executes an assessment for [action], returning the resulting token.
  Future<String> execute(String action);
}
