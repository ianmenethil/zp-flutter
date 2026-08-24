import 'dart:convert';
import 'dart:io';

import 'package:googleapis/recaptchaenterprise/v1.dart' as recaptcha;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

final _logger = Logger('recaptcha_verifier');

/// Masks a bearer-shaped secret the same partial way `server_app.dart`
/// redacts headers: first/last 3 characters kept, rest replaced with `...`.
String _maskSecret(String value) => value.length <= 6 ? '...' : '${value.substring(0, 3)}...${value.substring(value.length - 3)}';

/// Redacts the client token inside a logged assessment's `event`. Everything
/// else (email, phone, amount) is logged in the clear, matching this demo
/// backend's existing body-logging convention (see server_app.dart's
/// http_trace).
///
/// Takes the typed [assessment] rather than its `toJson()` output: that
/// output's `event` entry is still the nested `Event` object, not a decoded
/// Map — `Assessment.toJson()` doesn't recursively convert it, relying on
/// `jsonEncode`'s own `toJson()` recursion at serialize time — so masking
/// has to go through `assessment.event.token` directly.
Map<String, Object?> _redactAssessmentJson(
  recaptcha.GoogleCloudRecaptchaenterpriseV1Assessment assessment,
) {
  final json = assessment.toJson();
  final token = assessment.event?.token;
  if (token == null || token.isEmpty) return json;
  return {
    ...json,
    'event': {...assessment.event!.toJson(), 'token': _maskSecret(token)},
  };
}

/// Outcome of a reCAPTCHA Enterprise assessment.
class RecaptchaResult {
  /// Creates a [RecaptchaResult].
  const RecaptchaResult({required this.valid});

  /// Whether the assessment passed bot detection.
  final bool valid;
}

/// Verifies reCAPTCHA Enterprise tokens against Google Cloud.
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
}

/// [RecaptchaVerifier] backed by Google Cloud's reCAPTCHA Enterprise REST API.
final class GoogleCloudRecaptchaVerifier implements RecaptchaVerifier {
  /// Creates a [GoogleCloudRecaptchaVerifier] from a service account JSON
  /// string or a path to one.
  GoogleCloudRecaptchaVerifier(String serviceAccountJsonOrPath) : _credentials = _parseCredentials(serviceAccountJsonOrPath), _injectedApi = null;

  /// Bypasses service-account credential loading entirely, using [api]
  /// directly — for tests that back it with a fake `http.Client`.
  @visibleForTesting
  GoogleCloudRecaptchaVerifier.withApi(recaptcha.RecaptchaEnterpriseApi api) : _credentials = null, _injectedApi = api;

  final auth.ServiceAccountCredentials? _credentials;
  final recaptcha.RecaptchaEnterpriseApi? _injectedApi;
  auth.AuthClient? _client;

  static const _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

  static auth.ServiceAccountCredentials _parseCredentials(String raw) {
    final trimmed = raw.trim();
    final jsonStr = (trimmed.startsWith('{') && trimmed.endsWith('}')) ? trimmed : File(trimmed).readAsStringSync();
    return auth.ServiceAccountCredentials.fromJson(
      jsonDecode(jsonStr) as Map<String, Object?>,
    );
  }

  Future<recaptcha.RecaptchaEnterpriseApi> _api() async {
    final injectedApi = _injectedApi;
    if (injectedApi != null) return injectedApi;
    final client = _client ??= await auth.clientViaServiceAccount(_credentials!, _scopes);
    return recaptcha.RecaptchaEnterpriseApi(client);
  }

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
      final api = await _api();

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

      _logger.fine('reCAPTCHA assessment request: ${jsonEncode(_redactAssessmentJson(request))}');
      final response = await api.projects.assessments.create(request, 'projects/$projectNumber');
      _logger.fine('reCAPTCHA assessment response: ${jsonEncode(_redactAssessmentJson(response))}');

      final valid = response.tokenProperties?.valid ?? false;
      if (!valid) {
        _logger.warning('reCAPTCHA token invalid: reason=${response.tokenProperties?.invalidReason}');
        return const RecaptchaResult(valid: false);
      }

      final actionMatch = response.tokenProperties?.action == expectedAction;
      if (!actionMatch) {
        _logger.warning('reCAPTCHA action mismatch: expected="$expectedAction" got="${response.tokenProperties?.action}"');
        return const RecaptchaResult(valid: false);
      }

      final botScore = response.riskAnalysis?.score ?? 0.0;
      final isHuman = botScore >= 0.5;
      if (!isHuman) {
        _logger.warning('reCAPTCHA risk rejected: score=$botScore reasons=${response.riskAnalysis?.reasons}');
      }

      return RecaptchaResult(valid: isHuman);
    } on Object catch (e, st) {
      _logger.severe('reCAPTCHA verification error', e, st);
      // In a real integration, consider whether to fail open or fail closed
      // if the verification API is unreachable.
      return const RecaptchaResult(valid: false);
    }
  }
}
