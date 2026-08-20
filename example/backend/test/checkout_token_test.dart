/// Unit tests for the checkout-exchange capability token codec.
library;

import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';
import 'package:zenpay_example_backend/src/checkout_token.dart';
import 'package:zenpay_example_backend/src/models.dart' show CheckoutClient;

const _secret = 'test-checkout-token-secret-1234567890';

CheckoutTokenPayload _payload({num? amount = 10}) => CheckoutTokenPayload(
  merchantUniquePaymentId: 'M1',
  mode: 0,
  client: CheckoutClient.mobile,
  customerName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  timestamp: '2026-01-01T00:00:00',
  amount: amount,
);

void main() {
  test('mints a token that verifies back to the same claims', () {
    final token = createCheckoutToken(
      _payload(),
      _secret,
      expiresInSeconds: 300,
    );
    final result = verifyCheckoutToken(token, _secret);

    expect(result, isA<CheckoutTokenVerified>());
    final payload = (result as CheckoutTokenVerified).payload;
    expect(payload.merchantUniquePaymentId, 'M1');
    expect(payload.mode, 0);
    expect(payload.client, CheckoutClient.mobile);
    expect(payload.amount, 10);
  });

  test('preserves a null amount (e.g. Tokenise)', () {
    final token = createCheckoutToken(
      _payload(amount: null),
      _secret,
      expiresInSeconds: 300,
    );
    final result = verifyCheckoutToken(token, _secret) as CheckoutTokenVerified;

    expect(result.payload.amount, isNull);
  });

  test('rejects a token signed with a different secret', () {
    final token = createCheckoutToken(
      _payload(),
      _secret,
      expiresInSeconds: 300,
    );
    final result = verifyCheckoutToken(
      token,
      'a-different-secret-1234567890abcd',
    );

    expect(
      result,
      isA<CheckoutTokenFailure>().having(
        (f) => f.reason,
        'reason',
        CheckoutTokenFailureReason.badSignature,
      ),
    );
  });

  test('rejects a tampered claim', () {
    final token = createCheckoutToken(
      _payload(),
      _secret,
      expiresInSeconds: 300,
    );
    final tampered = 'X${token.substring(1)}';

    expect(verifyCheckoutToken(tampered, _secret), isA<CheckoutTokenFailure>());
  });

  test('rejects an expired token', () {
    final token = createCheckoutToken(
      _payload(),
      _secret,
      expiresInSeconds: -1,
    );

    expect(
      verifyCheckoutToken(token, _secret),
      isA<CheckoutTokenFailure>().having(
        (f) => f.reason,
        'reason',
        CheckoutTokenFailureReason.expired,
      ),
    );
  });

  test('rejects a malformed token', () {
    expect(
      verifyCheckoutToken('not-a-real-token', _secret),
      isA<CheckoutTokenFailure>().having(
        (f) => f.reason,
        'reason',
        CheckoutTokenFailureReason.malformed,
      ),
    );
  });

  test("a ZenPay attempt-scoped 't' return token is rejected as a checkout "
      'token (scope confusion)', () {
    final returnToken = createZpCallbackUrlToken(
      const ZpCallbackUrlTokenPayload(
        mode: ZpPluginMode.makePayment,
        merchantUniquePaymentId: 'M1',
        timestamp: '2026-01-01T00:00:00',
        paymentAmount: 10,
      ),
      _secret,
    );

    expect(
      verifyCheckoutToken(returnToken, _secret),
      isA<CheckoutTokenFailure>(),
    );
  });
}
