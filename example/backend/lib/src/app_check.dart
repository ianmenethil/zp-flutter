/// Firebase App Check token verification using Google's official REST API.
///
/// Calls `POST /v1beta/projects/{number}:verifyAppCheckToken` via the
/// official `googleapis_beta` + `googleapis_auth` packages — no third-party
/// JWT libraries. Injectable via [AppCheckVerifier] so tests never hit
/// Google's real endpoint.
library;

import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis_beta/firebaseappcheck/v1beta.dart' as appcheck;

/// Verifies Firebase App Check tokens. The default implementation calls
/// Google's REST API; tests inject a fake.
// Strategy interface for AppCheck token verification and test doubles.
abstract interface class AppCheckVerifier {
  /// Returns `true` if [token] is a valid App Check token for
  /// [projectNumber]. Returns `false` on any failure — never throws.
  Future<bool> verify(String token, String projectNumber);
}

/// Production [AppCheckVerifier] that calls Google's
/// `verifyAppCheckToken` REST endpoint via a Service Account.
final class FirebaseAppCheckVerifier implements AppCheckVerifier {
  /// Creates a verifier from a Service Account JSON key (file contents or path).
  FirebaseAppCheckVerifier(String serviceAccountJsonOrPath) : _credentials = _parseCredentials(serviceAccountJsonOrPath);

  final auth.ServiceAccountCredentials _credentials;
  auth.AuthClient? _client;

  static const _scopes = ['https://www.googleapis.com/auth/firebase'];

  static auth.ServiceAccountCredentials _parseCredentials(String raw) {
    final trimmed = raw.trim();
    final jsonStr = (trimmed.startsWith('{') && trimmed.endsWith('}')) ? trimmed : File(trimmed).readAsStringSync();
    return auth.ServiceAccountCredentials.fromJson(
      jsonDecode(jsonStr) as Map<String, Object?>,
    );
  }

  Future<auth.AuthClient> _authClient() async => _client ??= await auth.clientViaServiceAccount(_credentials, _scopes);

  @override
  Future<bool> verify(String token, String projectNumber) async {
    try {
      final client = await _authClient();
      final api = appcheck.FirebaseappcheckApi(client);
      await api.projects.verifyAppCheckToken(
        appcheck.GoogleFirebaseAppcheckV1betaVerifyAppCheckTokenRequest(
          appCheckToken: token,
        ),
        'projects/$projectNumber',
      );
      // If the call returns without throwing, the token is valid.
      return true;
    } on appcheck.DetailedApiRequestError catch (e) {
      // 403 = invalid/expired token, 400 = unsupported provider.
      if (e.status == 403 || e.status == 400) return false;
      rethrow;
    } on Object catch (_) {
      return false;
    }
  }

  /// Closes the underlying HTTP client. Call on server shutdown.
  void close() {
    _client?.close();
    _client = null;
  }
}
