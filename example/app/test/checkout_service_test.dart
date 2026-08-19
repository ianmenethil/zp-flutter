/// Unit tests for `checkout_service.dart` against a faked backend, using the
/// `MockClient` shipped by `package:http/testing.dart` — no live server.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:zenpay_example_app/features/checkout/services/checkout_service.dart';

void main() {
  final base = Uri.parse('http://localhost:8080');

  group('prepareCheckout', () {
    test(
      'POSTs to the checkout/token endpoint and returns the token',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{'checkoutToken': 'checkout-token-1'}),
            201,
          );
        });

        final checkoutToken = await prepareCheckout(base, <String, Object?>{
          'mode': 0,
          'paymentAmount': 10,
        }, client: client);

        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/v1/checkout/token');
        expect(captured.headers['content-type'], 'application/json');
        expect(
          captured.headers['idempotency-key']!.length,
          inInclusiveRange(16, 128),
        );
        expect(
          jsonDecode(captured.body) as Map<String, Object?>,
          containsPair('client', 'mobile'),
        );
        expect(captured.headers['x-firebase-appcheck'], isNull);
        expect(checkoutToken, 'checkout-token-1');
      },
    );

    test(
      'attaches x-firebase-appcheck header when appCheckToken is provided',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{'checkoutToken': 'checkout-token-2'}),
            201,
          );
        });

        final checkoutToken = await prepareCheckout(
          base,
          <String, Object?>{'mode': 0, 'paymentAmount': 10},
          client: client,
          appCheckToken: 'test-app-check-token-123',
        );

        expect(
          captured.headers['x-firebase-appcheck'],
          'test-app-check-token-123',
        );
        expect(checkoutToken, 'checkout-token-2');
      },
    );

    test('throws BackendError carrying the backend error code', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': 'SESSION_CONFIGURATION_REQUIRED',
          }),
          500,
        ),
      );

      await expectLater(
        prepareCheckout(base, <String, Object?>{}, client: client),
        throwsA(
          isA<BackendError>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.code, 'code', 'SESSION_CONFIGURATION_REQUIRED'),
        ),
      );
    });
  });

  group('exchangeCheckout', () {
    test(
      'POSTs with a Bearer checkoutToken and decodes the response',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'checkoutUrl': 'https://pay.sandbox.travelpay.com.au/launch',
            }),
            200,
          );
        });

        final exchanged = await exchangeCheckout(
          base,
          'checkout-token-1',
          client: client,
        );

        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/v1/checkout/exchange');
        expect(captured.headers['authorization'], 'Bearer checkout-token-1');
        expect(
          exchanged.checkoutUrl,
          'https://pay.sandbox.travelpay.com.au/launch',
        );
      },
    );
  });

  group('fetchStatus', () {
    test('GETs with the token query and decodes the status', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'successful',
            'callbackVerified': true,
          }),
          200,
        );
      });

      final status = await fetchStatus(base, 'signed-token', client: client);

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/v1/sessions');
      expect(captured.url.queryParameters['t'], 'signed-token');
      expect(status.status, 'successful');
      expect(status.callbackVerified, isTrue);
    });

    test('throws BackendError with a null code for an empty body', () async {
      final client = MockClient((request) async => http.Response('', 404));

      await expectLater(
        fetchStatus(base, 'signed-token', client: client),
        throwsA(
          isA<BackendError>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', isNull),
        ),
      );
    });
  });
}
