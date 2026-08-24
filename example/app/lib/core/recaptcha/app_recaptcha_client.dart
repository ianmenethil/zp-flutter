/// reCAPTCHA Enterprise client contract for this demo — web only.
///
/// The concrete implementation is `app_recaptcha_client_web.dart`, resolved
/// via `app_recaptcha_client_factory.dart`'s conditional import.
library;

/// A reCAPTCHA Enterprise client capable of minting an assessment token.
abstract class AppRecaptchaClient {
  /// Executes an assessment for [action], returning the resulting token.
  Future<String> execute(String action);
}
