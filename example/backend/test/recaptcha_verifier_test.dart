/// Unit tests for [GoogleCloudRecaptchaVerifier.verify], backed by a fake
/// `http.Client` (via `GoogleCloudRecaptchaVerifier.withApi`) instead of a
/// real Google Cloud service account — no network, no credentials.
library;

import 'dart:convert';

import 'package:googleapis/recaptchaenterprise/v1.dart' as recaptcha;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:zenpay_example_backend/src/recaptcha_verifier.dart';

/// Builds a [GoogleCloudRecaptchaVerifier] whose requests are answered by
/// [handler] instead of hitting the real reCAPTCHA Enterprise API. [handler]
/// receives the decoded request body.
GoogleCloudRecaptchaVerifier _fakeVerifier(Map<String, Object?> Function(Map<String, Object?> requestJson) handler) {
  final client = MockClient((request) async {
    final requestJson = jsonDecode(request.body) as Map<String, Object?>;
    return http.Response(jsonEncode(handler(requestJson)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
  return GoogleCloudRecaptchaVerifier.withApi(recaptcha.RecaptchaEnterpriseApi(client));
}

void main() {
  group('GoogleCloudRecaptchaVerifier.verify', () {
    test('sends token, siteKey, and expectedAction in the assessment request', () async {
      Map<String, Object?>? capturedRequest;
      final verifier = _fakeVerifier((requestJson) {
        capturedRequest = requestJson;
        return {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.9},
        };
      });

      await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      final event = capturedRequest!['event']! as Map<String, Object?>;
      expect(event['token'], 'client-token');
      expect(event['siteKey'], 'site-key-web');
      expect(event['expectedAction'], 'checkout');
    });

    test('includes transactionData when contact/payment fields are supplied', () async {
      Map<String, Object?>? capturedRequest;
      final verifier = _fakeVerifier((requestJson) {
        capturedRequest = requestJson;
        return {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.9},
        };
      });

      await verifier.verify(
        'client-token',
        '123456',
        'checkout',
        'site-key-web',
        email: 'jaina@zenpay.com.au',
        phone: '0400000000',
        accountId: 'ref-1',
        paymentAmount: 262.51,
      );

      final event = capturedRequest!['event']! as Map<String, Object?>;
      final transactionData = event['transactionData']! as Map<String, Object?>;
      expect(transactionData['value'], 262.51);
      final user = transactionData['user']! as Map<String, Object?>;
      expect(user['email'], 'jaina@zenpay.com.au');
      expect(user['phoneNumber'], '0400000000');
      expect(user['accountId'], 'ref-1');
    });

    test('omits transactionData when no contact/payment fields are supplied', () async {
      Map<String, Object?>? capturedRequest;
      final verifier = _fakeVerifier((requestJson) {
        capturedRequest = requestJson;
        return {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.9},
        };
      });

      await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      final event = capturedRequest!['event']! as Map<String, Object?>;
      expect(event.containsKey('transactionData'), isFalse);
    });

    test('rejects an invalid token', () async {
      final verifier = _fakeVerifier(
        (_) => {
          'tokenProperties': {'valid': false, 'invalidReason': 'EXPIRED'},
        },
      );

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isFalse);
    });

    test('rejects a valid token whose action does not match the expected action', () async {
      final verifier = _fakeVerifier(
        (_) => {
          'tokenProperties': {'valid': true, 'action': 'login'},
          'riskAnalysis': {'score': 0.9},
        },
      );

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isFalse);
    });

    test('rejects a valid, action-matched token with a low bot score', () async {
      final verifier = _fakeVerifier(
        (_) => {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.1},
        },
      );

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isFalse);
    });

    test('accepts a valid, action-matched token with a high bot score', () async {
      final verifier = _fakeVerifier(
        (_) => {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.9},
        },
      );

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isTrue);
    });

    test('a bot score of exactly 0.5 counts as human (boundary)', () async {
      final verifier = _fakeVerifier(
        (_) => {
          'tokenProperties': {'valid': true, 'action': 'checkout'},
          'riskAnalysis': {'score': 0.5},
        },
      );

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isTrue);
    });

    test('returns invalid when the API call throws', () async {
      final client = MockClient((request) async => http.Response('boom', 500));
      final verifier = GoogleCloudRecaptchaVerifier.withApi(recaptcha.RecaptchaEnterpriseApi(client));

      final result = await verifier.verify('client-token', '123456', 'checkout', 'site-key-web');

      expect(result.valid, isFalse);
    });
  });
}
