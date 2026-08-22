import 'dart:convert';
import 'dart:io';

import 'package:googleapis/recaptchaenterprise/v1.dart' as recaptcha;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:logging/logging.dart';

final _logger = Logger('recaptcha_verifier');

/// Outcome of a reCAPTCHA Enterprise assessment.
class RecaptchaResult {
  /// Creates a [RecaptchaResult].
  const RecaptchaResult({required this.valid, this.assessmentName, this.transactionRisk});

  /// Whether the assessment passed bot/fraud checks.
  final bool valid;

  /// The assessment resource name, for later annotation.
  final String? assessmentName;

  /// Fraud Prevention transaction risk score, when computed.
  final double? transactionRisk;
}

/// Verifies reCAPTCHA Enterprise tokens and assessments against Google Cloud.
abstract interface class RecaptchaVerifier {
  /// Verifies a client-supplied [token] for [expectedAction] under [siteKey].
  Future<RecaptchaResult> verify(
    String token,
    String projectNumber,
    String expectedAction,
    String siteKey, {
    String? email,
    String? phone,
    String? accountId,
    double? paymentAmount,
  });

  /// Records the real-world outcome of an assessment, for Google's model.
  Future<void> annotate({
    required String projectNumber,
    required String assessmentName,
    required String transactionEvent,
    String? reason,
  });

  /// Creates a token-less, server-only assessment for callback-side risk
  /// scoring (no client token is available at that point).
  Future<RecaptchaResult> createApiOnlyAssessment(
    String projectNumber,
    String siteKey, {
    required String cardBin,
    required String cardLastFour,
    required String paymentMethod,
    String? email,
    String? phone,
    String? accountId,
    double? paymentAmount,
    String? transactionId,
    String? currencyCode,
  });
}

/// [RecaptchaVerifier] backed by Google Cloud's reCAPTCHA Enterprise REST API.
final class GoogleCloudRecaptchaVerifier implements RecaptchaVerifier {
  /// Creates a [GoogleCloudRecaptchaVerifier] from a service account JSON
  /// string or a path to one.
  GoogleCloudRecaptchaVerifier(String serviceAccountJsonOrPath) : _credentials = _parseCredentials(serviceAccountJsonOrPath);

  final auth.ServiceAccountCredentials _credentials;
  auth.AuthClient? _client;

  static const _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

  static auth.ServiceAccountCredentials _parseCredentials(String raw) {
    final trimmed = raw.trim();
    final jsonStr = (trimmed.startsWith('{') && trimmed.endsWith('}')) ? trimmed : File(trimmed).readAsStringSync();
    return auth.ServiceAccountCredentials.fromJson(
      jsonDecode(jsonStr) as Map<String, Object?>,
    );
  }

  Future<auth.AuthClient> _authClient() async => _client ??= await auth.clientViaServiceAccount(_credentials, _scopes);

  @override
  Future<RecaptchaResult> verify(
    String token,
    String projectNumber,
    String expectedAction,
    String siteKey, {
    String? email,
    String? phone,
    String? accountId,
    double? paymentAmount,
  }) async {
    try {
      final client = await _authClient();
      final api = recaptcha.RecaptchaEnterpriseApi(client);

      final request = recaptcha.GoogleCloudRecaptchaenterpriseV1Assessment(
        event: recaptcha.GoogleCloudRecaptchaenterpriseV1Event(
          token: token,
          siteKey: siteKey,
          expectedAction: expectedAction,
          transactionData: (email != null || phone != null || accountId != null || paymentAmount != null)
              ? recaptcha.GoogleCloudRecaptchaenterpriseV1TransactionData(
                  user: recaptcha.GoogleCloudRecaptchaenterpriseV1TransactionDataUser(
                    email: email,
                    phoneNumber: phone,
                    accountId: accountId,
                  ),
                  value: paymentAmount,
                )
              : null,
        ),
      );

      final response = await api.projects.assessments.create(request, 'projects/$projectNumber');

      final valid = response.tokenProperties?.valid ?? false;
      if (!valid) return const RecaptchaResult(valid: false);

      final actionMatch = response.tokenProperties?.action == expectedAction;
      if (!actionMatch) return const RecaptchaResult(valid: false);

      final botScore = response.riskAnalysis?.score ?? 0.0;
      final isHuman = botScore >= 0.5;

      final transactionRisk = response.fraudPreventionAssessment?.transactionRisk;
      final isFraudulent = transactionRisk != null && transactionRisk >= 0.5;

      return RecaptchaResult(valid: isHuman && !isFraudulent, assessmentName: response.name);
    } on Object catch (e, st) {
      _logger.severe('reCAPTCHA verification error', e, st);
      // In a real integration, consider whether to fail open or fail closed
      // if the verification API is unreachable.
      return const RecaptchaResult(valid: false);
    }
  }

  @override
  Future<RecaptchaResult> createApiOnlyAssessment(
    String projectNumber,
    String siteKey, {
    required String cardBin,
    required String cardLastFour,
    required String paymentMethod,
    String? email,
    String? phone,
    String? accountId,
    double? paymentAmount,
    String? transactionId,
    String? currencyCode,
  }) async {
    try {
      final client = await _authClient();
      final api = recaptcha.RecaptchaEnterpriseApi(client);

      final request = recaptcha.GoogleCloudRecaptchaenterpriseV1Assessment(
        event: recaptcha.GoogleCloudRecaptchaenterpriseV1Event(
          siteKey: siteKey,
          expectedAction: 'checkout_callback',
          transactionData: recaptcha.GoogleCloudRecaptchaenterpriseV1TransactionData(
            transactionId: transactionId,
            currencyCode: currencyCode,
            cardBin: cardBin,
            cardLastFour: cardLastFour,
            paymentMethod: paymentMethod,
            // Google's API-only Integration requires a billing address or the
            // call 400s (see fraud.md); this app never collects one, so a
            // fixed AU/2000 stands in until real billing data is captured.
            billingAddress: recaptcha.GoogleCloudRecaptchaenterpriseV1TransactionDataAddress(
              regionCode: 'AU',
              postalCode: '2000',
            ),
            user: (email != null || phone != null || accountId != null)
                ? recaptcha.GoogleCloudRecaptchaenterpriseV1TransactionDataUser(
                    email: email,
                    phoneNumber: phone,
                    accountId: accountId,
                  )
                : null,
            value: paymentAmount,
          ),
        ),
      );

      final response = await api.projects.assessments.create(request, 'projects/$projectNumber');

      final botScore = response.riskAnalysis?.score ?? 0.0;
      final isHuman = botScore >= 0.5;

      final transactionRisk = response.fraudPreventionAssessment?.transactionRisk;
      final isFraudulent = transactionRisk != null && transactionRisk >= 0.5;

      return RecaptchaResult(valid: isHuman && !isFraudulent, assessmentName: response.name, transactionRisk: transactionRisk);
    } on Object catch (e, st) {
      _logger.severe('reCAPTCHA API-only assessment error', e, st);
      return const RecaptchaResult(valid: false);
    }
  }

  @override
  Future<void> annotate({
    required String projectNumber,
    required String assessmentName,
    required String transactionEvent,
    String? reason,
  }) async {
    try {
      final client = await _authClient();
      final api = recaptcha.RecaptchaEnterpriseApi(client);

      final request = recaptcha.GoogleCloudRecaptchaenterpriseV1AnnotateAssessmentRequest(
        annotation: transactionEvent,
        reasons: reason != null ? [reason] : null,
      );

      await api.projects.assessments.annotate(request, assessmentName);
    } on Object {
      // Annotations are best-effort fire-and-forget in this example.
    }
  }
}
