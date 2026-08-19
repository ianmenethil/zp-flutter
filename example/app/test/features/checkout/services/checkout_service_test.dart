/// Unit tests for [ExchangeResponse.fromJson] and [StatusResponse.fromJson].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_example_app/features/checkout/services/checkout_service.dart';

void main() {
  group('ExchangeResponse.fromJson', () {
    test('decodes a valid payload', () {
      final exchanged = ExchangeResponse.fromJson({
        'checkoutUrl': 'https://pay.example.com/checkout',
      });

      expect(exchanged.checkoutUrl, 'https://pay.example.com/checkout');
    });

    test('throws when a required field is missing', () {
      expect(() => ExchangeResponse.fromJson({}), throwsA(isA<TypeError>()));
    });
  });

  group('StatusResponse.fromJson', () {
    test('decodes a valid payload with optional fields present', () {
      final status = StatusResponse.fromJson({
        'status': 'successful',
        'callbackVerified': true,
        'paymentReference': 'PAY-1',
        'preauthReference': null,
        'tokenReference': null,
        'failureCode': null,
        'failureReason': null,
        'zenPayStatusCode': 3,
        'callbackPayload': {
          'response': {'paymentReference': 'PAY-1'},
          'validationCode': 'abc123',
        },
      });

      expect(status.status, 'successful');
      expect(status.callbackVerified, true);
      expect(status.paymentReference, 'PAY-1');
      expect(status.zenPayStatusCode, 3);
      expect(status.callbackPayload?['validationCode'], 'abc123');
    });

    test('decodes a valid payload with optional fields absent', () {
      final status = StatusResponse.fromJson({
        'status': 'created',
        'callbackVerified': false,
      });

      expect(status.paymentReference, isNull);
      expect(status.preauthReference, isNull);
      expect(status.tokenReference, isNull);
      expect(status.failureCode, isNull);
      expect(status.failureReason, isNull);
      expect(status.zenPayStatusCode, isNull);
      expect(status.callbackPayload, isNull);
    });

    test('throws when a required field is missing', () {
      expect(
        () => StatusResponse.fromJson({'status': 'created'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
