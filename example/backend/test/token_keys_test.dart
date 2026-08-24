/// Tests proving `token_keys.dart`'s domain separation: a token minted for
/// one purpose fails signature verification under another purpose's
/// derived key, before any scope or shape check ever runs.
library;

import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';
import 'package:zenpay_example_backend/src/checkout_token.dart';
import 'package:zenpay_example_backend/src/config.dart';
import 'package:zenpay_example_backend/src/models.dart' show CheckoutClient;
import 'package:zenpay_example_backend/src/token_keys.dart';

AppConfig _config() => AppConfig(
  port: 0,
  publicBaseUrl: Uri.parse('http://127.0.0.1:7099'),
  allowedAppOrigin: 'http://localhost:3000',
  appReturnUriWeb: Uri.parse('https://localhost:3000/'),
  checkoutStatusTtlMinutes: 60,
  tokenSecret: 'test-token-keys-root-secret-1234567890',
  checkoutTokenTtlSeconds: 300,
  checkoutRateLimitPerMinute: 1000,
  firebaseProjectNumber: '',
  firebaseServiceAccountJson: '',
  recaptchaSiteKeyWeb: 'web_key',
  zenPay: ZenPayConfig(
    hppEndpointUrl: Uri.parse('https://pay.sandbox.travelpay.com.au/Online/v5'),
    allowedCheckoutHosts: {'pay.sandbox.travelpay.com.au'},
    credentials: const ZenPayCredentials(
      merchantCode: 'merchant-code',
      apiKey: 'test-api-key',
      username: 'test-username',
      password: 'test-password',
    ),
  ),
);

const _checkoutPayload = CheckoutTokenPayload(
  merchantUniquePaymentId: 'M1',
  mode: 0,
  client: CheckoutClient.mobile,
  customerName: 'Jane Doe',
  customerEmail: 'jane@example.com',
  timestamp: '2026-01-01T00:00:00',
  amount: 10,
);

String _callbackToken(AppConfig config) => createZpCallbackUrlToken(
  const ZpCallbackUrlTokenPayload(
    mode: ZpPluginMode.makePayment,
    merchantUniquePaymentId: ZpMupid('M1'),
    timestamp: ZpTimestamp('2026-01-01T00:00:00'),
    paymentAmount: 10,
  ),
  callbackTokenKey(config),
);

void main() {
  test('derives a different key per purpose from the same root secret', () {
    final config = _config();

    expect(checkoutTokenKey(config), isNot(callbackTokenKey(config)));
  });

  test('derivation is deterministic for the same root secret and purpose', () {
    expect(checkoutTokenKey(_config()), checkoutTokenKey(_config()));
    expect(callbackTokenKey(_config()), callbackTokenKey(_config()));
  });

  group('cross-purpose verification always fails', () {
    test('checkoutToken cannot verify as the callback (t) token', () {
      final config = _config();
      final checkoutToken = createCheckoutToken(
        _checkoutPayload,
        checkoutTokenKey(config),
        expiresInSeconds: 300,
      );

      expect(
        verifyZpCallbackUrlToken(checkoutToken, callbackTokenKey(config)),
        isA<ZpCallbackUrlTokenFailure>(),
      );
    });

    test('the callback (t) token cannot verify as a checkoutToken', () {
      final config = _config();
      final callbackToken = _callbackToken(config);

      expect(
        verifyCheckoutToken(callbackToken, checkoutTokenKey(config)),
        isA<CheckoutTokenFailure>(),
      );
    });
  });
}
