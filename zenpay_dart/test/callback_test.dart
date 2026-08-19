/// Tests for `verifyZpCallback` across all four payment modes, using golden
/// `ValidationCode` digests moved unchanged from the Dart backend rewrite's
/// `callback_verification_test.dart` (see
/// `test/fixtures/zp_hcp_v0_1_30_vectors.json`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';

Map<String, Object?> _loadVectors() => jsonDecode(
  File('test/fixtures/zp_hcp_v0_1_30_vectors.json').readAsStringSync(),
) as Map<String, Object?>;

void main() {
  final vectors = _loadVectors();
  final credentials = vectors['credentials'] as Map<String, Object?>;
  final mupid = vectors['mupid'] as String;
  final callbacks = vectors['callbacks'] as Map<String, Object?>;

  ZpVerifyCallbackContext contextFor(num amount) => ZpVerifyCallbackContext(
    apiKey: credentials['apiKey'] as String,
    username: credentials['username'] as String,
    password: credentials['password'] as String,
    paymentAmount: amount,
    merchantUniquePaymentId: ZpMupid(mupid),
  );

  group('mode 0 (payment) — golden digest moved unchanged from the Dart backend rewrite', () {
    final vector = callbacks['mode0Payment'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final amount = vector['paymentAmount'] as num;

    Map<String, Object?> body({String? reference, String? validationCode}) => {
      'response': {
        'merchantUniquePaymentId': mupid,
        'paymentReference': reference ?? vector['reference'],
        'paymentStatus': 3,
      },
      'validationCode': validationCode ?? vector['validationCode'],
    };

    test('accepts the correctly hashed callback', () {
      final result = verifyZpCallback(mode, body(), contextFor(amount));
      expect(result, isA<ZpCallbackVerified>());
    });

    test('rejects a tampered validationCode', () {
      final result = verifyZpCallback(
        mode,
        body(validationCode: '0'.padLeft(128, '0')),
        contextFor(amount),
      );
      expect(result, isA<ZpCallbackRejected>());
    });

    test('rejects a callback whose reference was swapped', () {
      final result = verifyZpCallback(
        mode,
        body(reference: 'PAY-999'),
        contextFor(amount),
      );
      expect(result, isA<ZpCallbackRejected>());
    });

    test('rejects an amount that does not match the launched context', () {
      final result = verifyZpCallback(mode, body(), contextFor(10));
      expect(result, isA<ZpCallbackRejected>());
    });

    test('reports a body that does not match the mode schema as malformed', () {
      final result = verifyZpCallback(mode, const {
        'nonsense': true,
      }, contextFor(amount));
      expect(result, isA<ZpCallbackMalformed>());
      if (result is ZpCallbackMalformed) {
        expect(result.message, contains('body must contain'));
      }
    });

    test(
      'verifies regardless of which extra business or card/account-shaped '
      'fields the response carries — this SDK checks the hash, nothing else',
      () {
        // Extra fields aren't part of the hash pipe, so adding them here
        // doesn't invalidate the golden validationCode above. There is
        // nothing to read off the result: verifyZpCallback returns no data
        // (mirrors `@ianmenethil/zp-hcp`'s TypeScript verifyZpCallback) — the
        // caller already holds this same `response` map and reads whatever
        // it needs from it directly.
        final result = verifyZpCallback(mode, {
          'response': {
            'merchantUniquePaymentId': mupid,
            'paymentReference': vector['reference'],
            'paymentStatus': 3,
            'customerName': 'Jane Doe',
            'cardCategory': 'Credit',
            'additionalData': {'authCode': 'AUTH123'},
            'token': 'CARD-TOKEN-ABC123',
            // Card/account-shaped — the SDK does authenticity verification
            // only, so these don't affect the result either.
            'accountOrCardNo': '4111********1111',
            'paymentCard': 'VISA',
            'cardHolderName': 'Jane Smith',
          },
          'validationCode': vector['validationCode'],
        }, contextFor(amount));

        expect(result, isA<ZpCallbackVerified>());
      },
    );

    group('validateZpCallbackBody', () {
      test('returns null for a well-shaped body', () {
        expect(validateZpCallbackBody(mode, body()), isNull);
      });

      test('flags an empty reference without checking authenticity', () {
        final failure = validateZpCallbackBody(mode, body(reference: ''));
        expect(failure, isA<ZpCallbackMalformed>());
        expect(failure?.message, contains('paymentReference'));
      });

      test('flags a non-hex validationCode', () {
        final failure = validateZpCallbackBody(
          mode,
          body(validationCode: 'not-hex'),
        );
        expect(failure?.message, contains('128-character hex string'));
      });

      test('does not reject a tampered validationCode — shape only', () {
        // Unlike verifyZpCallback, shape validation never hashes: a body
        // with a wrong-but-correctly-shaped validationCode still passes.
        expect(
          validateZpCallbackBody(
            mode,
            body(validationCode: '0'.padLeft(128, '0')),
          ),
          isNull,
        );
      });

      test('reports a body missing response/validationCode as malformed', () {
        final failure = validateZpCallbackBody(mode, const {'nonsense': true});
        expect(failure?.message, contains('body must contain'));
      });
    });
  });

  test('mode 1 (tokenise) — golden digest for an amountless attempt', () {
    final vector = callbacks['mode1Tokenise'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final result = verifyZpCallback(mode, {
      'response': {'token': vector['reference']},
      'validationCode': vector['validationCode'],
    }, contextFor(vector['paymentAmount'] as num));
    expect(result, isA<ZpCallbackVerified>());
  });

  test(
    'mode 1 (tokenise) verifies with paymentDetail and doRedirect present',
    () {
      final vector = callbacks['mode1Tokenise'] as Map<String, Object?>;
      final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
      final result = verifyZpCallback(mode, {
        'response': {
          'token': vector['reference'],
          'doRedirect': true,
          'paymentDetail': {
            'customerFee': 1.5,
            'merchantFee': 0.5,
            'processingAmount': 51.4,
            'paymentAmount': 49.9,
          },
        },
        'validationCode': vector['validationCode'],
      }, contextFor(vector['paymentAmount'] as num));

      expect(result, isA<ZpCallbackVerified>());
    },
  );

  test('mode 2 (custom payment) — hash uses "0" but a positive context amount is still required', () {
    final vector = callbacks['mode2CustomPayment'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final body = {
      'response': {
        'merchantUniquePaymentId': mupid, // needed to pass mupid check
        'paymentReference': vector['reference'],
        'paymentStatus': 3,
      },
      'validationCode': vector['validationCode'],
    };

    expect(
      verifyZpCallback(mode, body, contextFor(vector['paymentAmount'] as num)),
      isA<ZpCallbackVerified>(),
    );
    // Preserves the installed zp-hcp@0.1.30 quirk: mode 2 always hashes
    // amount "0", but a non-positive context amount is still rejected.
    final rejected = verifyZpCallback(mode, body, contextFor(0));
    expect(rejected, isA<ZpCallbackRejected>());
  });

  test('mode 3 (preauthorization) — golden digest', () {
    final vector = callbacks['mode3Preauthorization'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final result = verifyZpCallback(mode, {
      'response': {'preauthReference': vector['reference'], 'preauthStatus': 3},
      'validationCode': vector['validationCode'],
    }, contextFor(vector['paymentAmount'] as num));
    expect(result, isA<ZpCallbackVerified>());
  });

  test('mode 3 (preauthorization) verifies with preauthAmount/preauthExpiryAt present', () {
    final vector = callbacks['mode3Preauthorization'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final result = verifyZpCallback(mode, {
      'response': {
        'preauthReference': vector['reference'],
        'preauthStatus': 3,
        'preauthStatusString': 'Held',
        'preauthAmount': 100.0,
        'preauthExpiryAt': '2026-03-01T00:00:00',
      },
      'validationCode': vector['validationCode'],
    }, contextFor(vector['paymentAmount'] as num));

    expect(result, isA<ZpCallbackVerified>());
  });

  test('rejects credentials shorter than 5 characters', () {
    final vector = callbacks['mode0Payment'] as Map<String, Object?>;
    final mode = ZpPluginMode.fromWireValue(vector['mode'] as int);
    final result = verifyZpCallback(
      mode,
      {
        'response': {
          'merchantUniquePaymentId': mupid,
          'paymentReference': vector['reference'],
        },
        'validationCode': vector['validationCode'],
      },
      const ZpVerifyCallbackContext(
        apiKey: 'ab',
        username: 'golden-username',
        password: 'golden-password',
        paymentAmount: 25.5,
        merchantUniquePaymentId: ZpMupid('golden-mupid-0001'),
      ),
    );
    expect(result, isA<ZpCallbackRejected>());
  });
}
