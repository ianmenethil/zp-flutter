/// HTTP-layer tests for the example backend.
///
/// Drives the real Shelf handler over real loopback HTTP. Nothing here calls
/// ZenPay: the backend never makes an outbound request at launch time.
library;

import 'dart:convert';
import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart' show LogRecord, Logger;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';
import 'package:zenpay_example_backend/src/app_check.dart';
import 'package:zenpay_example_backend/src/attempt_store.dart';
import 'package:zenpay_example_backend/src/checkout_token.dart' show CheckoutTokenVerified, verifyCheckoutToken;
import 'package:zenpay_example_backend/src/config.dart';
import 'package:zenpay_example_backend/src/models.dart';
import 'package:zenpay_example_backend/src/server_app.dart';
import 'package:zenpay_example_backend/src/token_keys.dart' show callbackTokenKey, checkoutTokenKey;

const _apiKey = 'test-api-key';
const _username = 'test-username';
const _password = 'test-password';
const _tokenSecret = 'test-token-secret-1234567890-abcdef';

/// Always-pass / configurable App Check verifier for tests.
final class _FakeAppCheckVerifier implements AppCheckVerifier {
  _FakeAppCheckVerifier({this.shouldPass = true});
  bool shouldPass;

  @override
  Future<bool> verify(String token, String projectNumber) async => shouldPass;
}

/// Test [AppConfig] with fixed, known ZenPay credentials so callback
/// signatures can be recomputed with [_sign].
AppConfig _config({
  int checkoutRateLimitPerMinute = 1000,
  String firebaseProjectNumber = '',
  String firebaseServiceAccountJson = '',
}) => AppConfig(
  port: 0,
  publicBaseUrl: Uri.parse('http://127.0.0.1:7099'),
  allowedAppOrigin: 'http://localhost:3000',
  appReturnUriWeb: Uri.parse('https://localhost:3000/'),
  checkoutStatusTtlMinutes: 60,
  tokenSecret: _tokenSecret,
  checkoutTokenTtlSeconds: 300,
  checkoutRateLimitPerMinute: checkoutRateLimitPerMinute,
  firebaseProjectNumber: firebaseProjectNumber,
  firebaseServiceAccountJson: firebaseServiceAccountJson,
  zenPay: ZenPayConfig(
    hppEndpointUrl: Uri.parse('https://pay.sandbox.travelpay.com.au/Online/v5'),
    allowedCheckoutHosts: {'pay.sandbox.travelpay.com.au'},
    credentials: const ZenPayCredentials(
      merchantCode: 'merchant-code',
      apiKey: _apiKey,
      username: _username,
      password: _password,
    ),
  ),
);

/// A [CheckoutAttempt] fixture pre-seeded directly into the store, bypassing
/// the checkout-token flow for tests that only need an existing attempt.
CheckoutAttempt _attempt({
  String merchantUniquePaymentId = 'att-lookup',
  CheckoutClient client = CheckoutClient.mobile,
  int mode = 0,
  num? amount = 49.90,
  MerchantPaymentStatus status = MerchantPaymentStatus.created,
}) => CheckoutAttempt(
  merchantUniquePaymentId: merchantUniquePaymentId,
  idempotencyKey: 'idempotency-key-$merchantUniquePaymentId',
  mode: mode,
  client: client,
  amount: amount,
  customerName: 'Test User',
  customerEmail: 'test@example.com',
  zenPayTimestamp: createZpTimestamp().value,
  createdAt: DateTime.now().toUtc(),
  status: status,
);

/// Recomputes the SHA3-512 `ValidationCode` ZenPay would send for a callback,
/// using the same `apiKey|username|password|mode|amount|mupid|reference`
/// hash pipe `verifyZpCallback` checks against.
String _sign(int mode, String amountField, String mupid, String reference) => sha3_512
    .string(
      [
        _apiKey,
        _username,
        _password,
        mode.toString(),
        amountField,
        mupid,
        reference,
      ].join('|'),
    )
    .hex();

/// A `t` token verifying to [merchantUniquePaymentId], as `/return` and the
/// status lookup require. Mirrors what `session_service.dart` mints — same
/// derived key, not the raw root secret (`token_keys.dart`).
String _token({
  required String merchantUniquePaymentId,
  int mode = 0,
  num amount = 49.90,
}) => createZpCallbackUrlToken(
  ZpCallbackUrlTokenPayload(
    mode: ZpPluginMode.fromWireValue(mode),
    merchantUniquePaymentId: merchantUniquePaymentId,
    timestamp: createZpTimestamp().value,
    paymentAmount: amount,
  ),
  callbackTokenKey(_config()),
);

/// A valid `POST /api/v1/checkout/token` request body.
Map<String, Object?> _prepareBody({
  int mode = 0,
  num? paymentAmount = 10,
  String customerEmail = 'jane@example.com',
}) => {
  'customerName': 'Jane Doe',
  'customerEmail': customerEmail,
  'customerReference': 'ORDER-REF',
  'mode': mode,
  'paymentAmount': ?paymentAmount,
};

void main() {
  late HttpServer server;
  late String base;
  late AttemptStore store;
  late AppConfig config;

  Future<void> startServer(
    AppConfig testConfig, {
    AppCheckVerifier? appCheckVerifier,
  }) async {
    config = testConfig;
    store = AttemptStore();
    server = await shelf_io.serve(
      buildHandler(config, store, appCheckVerifier: appCheckVerifier),
      InternetAddress.loopbackIPv4,
      0,
    );
    base = 'http://127.0.0.1:${server.port}';
  }

  setUp(() => startServer(_config()));

  tearDown(() async {
    await server.close(force: true);
  });

  Future<http.Response> call(
    String path, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, Uri.parse('$base$path'));
    if (headers != null) request.headers.addAll(headers);
    if (body != null) request.body = body is String ? body : jsonEncode(body);
    return http.Response.fromStream(await request.send());
  }

  Future<http.Response> prepare({
    Map<String, Object?>? body,
    String idempotencyKey = 'idempotency-key-prepare-0001',
    String client = 'web',
  }) => call(
    '/api/v1/checkout/token',
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'idempotency-key': idempotencyKey,
      'x-client': client,
    },
    body: body ?? _prepareBody(),
  );

  Future<http.Response> exchange(String checkoutToken) => call(
    '/api/v1/checkout/exchange',
    method: 'POST',
    headers: {'authorization': 'Bearer $checkoutToken'},
  );

  /// Prepares and exchanges a fresh checkout end to end, returning the
  /// decoded `checkoutToken` claims plus the exchange response body.
  Future<
    ({
      String checkoutToken,
      String merchantUniquePaymentId,
      Map<String, Object?> exchanged,
    })
  >
  freshCheckout({
    Map<String, Object?>? body,
    String idempotencyKey = 'idempotency-key-prepare-0001',
  }) async {
    final prepareResponse = await prepare(
      body: body,
      idempotencyKey: idempotencyKey,
    );
    final checkoutToken = (jsonDecode(prepareResponse.body) as Map<String, Object?>)['checkoutToken']! as String;
    final payload = (verifyCheckoutToken(checkoutToken, checkoutTokenKey(_config())) as CheckoutTokenVerified).payload;
    final exchangeResponse = await exchange(checkoutToken);
    return (
      checkoutToken: checkoutToken,
      merchantUniquePaymentId: payload.merchantUniquePaymentId,
      exchanged: jsonDecode(exchangeResponse.body) as Map<String, Object?>,
    );
  }

  group('POST /api/v1/checkout/token', () {
    test('mode 0 requires a paymentAmount', () async {
      final response = await prepare(body: _prepareBody(paymentAmount: null));
      expect(response.statusCode, 400);
      expect(jsonDecode(response.body), {'error': 'INVALID_CHECKOUT_AMOUNT'});
    });

    test('mode 0 accepts any positive amount', () async {
      final response = await prepare(body: _prepareBody(paymentAmount: 361.16));
      expect(response.statusCode, 201);
    });

    test('rejects a missing or unknown X-Client header', () async {
      final missing = await call(
        '/api/v1/checkout/token',
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'idempotency-key': 'idempotency-key-no-client-header',
        },
        body: _prepareBody(),
      );
      expect(missing.statusCode, 400);
      expect(jsonDecode(missing.body), {'error': 'INVALID_CHECKOUT_CLIENT'});

      final unknown = await prepare(client: 'iframe');
      expect(unknown.statusCode, 400);
      expect(jsonDecode(unknown.body), {'error': 'INVALID_CHECKOUT_CLIENT'});
    });

    test('echoes the caller-supplied X-Request-Id on the response', () async {
      final response = await call(
        '/api/v1/checkout/token',
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'idempotency-key': 'idempotency-key-with-request-id',
          'x-client': 'web',
          'x-request-id': 'client-side-id-123',
        },
        body: _prepareBody(),
      );
      expect(response.statusCode, 201);
      expect(response.headers['x-request-id'], 'client-side-id-123');
    });

    test('mode 0 with a valid amount returns a checkout token', () async {
      final response = await prepare();
      expect(response.statusCode, 201);
      final json = jsonDecode(response.body) as Map<String, Object?>;
      expect(json['checkoutToken'], isNotEmpty);
      expect(json.containsKey('sessionId'), isFalse);
      expect(json.containsKey('merchantUniquePaymentId'), isFalse);
      expect(json.containsKey('attemptId'), isFalse);
    });

    test('mode 1 (Tokenise) does not require a paymentAmount', () async {
      final response = await prepare(
        body: _prepareBody(mode: 1, paymentAmount: null),
      );
      expect(response.statusCode, 201);
    });

    test('mode 1 without a paymentAmount omits it from the launch URL', () async {
      final result = await freshCheckout(
        body: _prepareBody(mode: 1, paymentAmount: null),
        idempotencyKey: 'idempotency-key-tokenise-unpriced',
      );
      final checkoutUrl = Uri.parse(result.exchanged['checkoutUrl']! as String);
      expect(checkoutUrl.queryParameters.containsKey('paymentAmount'), isFalse);
    });

    test('mode 1 with a paymentAmount passes it through for fee display', () async {
      final result = await freshCheckout(
        body: _prepareBody(mode: 1, paymentAmount: 999),
        idempotencyKey: 'idempotency-key-tokenise-priced',
      );
      final checkoutUrl = Uri.parse(result.exchanged['checkoutUrl']! as String);
      expect(checkoutUrl.queryParameters['paymentAmount'], '999');
    });

    test('mode 2 (Custom Payment) requires a positive paymentAmount', () async {
      final missing = await prepare(
        body: _prepareBody(mode: 2, paymentAmount: null),
      );
      expect(missing.statusCode, 400);
      expect(jsonDecode(missing.body), {'error': 'INVALID_CHECKOUT_AMOUNT'});

      final ok = await prepare(
        body: _prepareBody(mode: 2, paymentAmount: 15.5),
      );
      expect(ok.statusCode, 201);
    });

    test(
      'mode 3 (Pre-Auth) requires a paymentAmount, same as mode 0',
      () async {
        final response = await prepare(
          body: _prepareBody(mode: 3, paymentAmount: null),
        );
        expect(response.statusCode, 400);
        expect(jsonDecode(response.body), {'error': 'INVALID_CHECKOUT_AMOUNT'});
      },
    );

    test(
      'a repeated Idempotency-Key re-mints a token for the same attempt',
      () async {
        final first = await freshCheckout(
          idempotencyKey: 'idempotency-key-dup',
        );
        final secondPrepare = await prepare(
          idempotencyKey: 'idempotency-key-dup',
        );
        final secondToken = (jsonDecode(secondPrepare.body) as Map<String, Object?>)['checkoutToken']! as String;
        final secondPayload = (verifyCheckoutToken(secondToken, checkoutTokenKey(_config())) as CheckoutTokenVerified).payload;

        expect(secondPrepare.statusCode, 201);
        expect(
          secondPayload.merchantUniquePaymentId,
          first.merchantUniquePaymentId,
        );
      },
    );

    test('a reused Idempotency-Key with different order fields 409s', () async {
      await prepare(idempotencyKey: 'idempotency-key-conflict');
      final response = await prepare(
        body: _prepareBody(customerEmail: 'someone-else@example.com'),
        idempotencyKey: 'idempotency-key-conflict',
      );
      expect(response.statusCode, 409);
      expect(jsonDecode(response.body), {'error': 'IDEMPOTENCY_KEY_REUSED'});
    });

    test(
      'rejects a checkout-creation burst once the per-IP limit trips',
      () async {
        await server.close(force: true);
        await startServer(_config(checkoutRateLimitPerMinute: 1));

        final first = await prepare(idempotencyKey: 'idempotency-key-rl-1');
        final second = await prepare(idempotencyKey: 'idempotency-key-rl-2');

        expect(first.statusCode, 201);
        expect(second.statusCode, 429);
        expect(jsonDecode(second.body), {'error': 'RATE_LIMITED'});
      },
    );
  });

  group('POST /api/v1/checkout/exchange', () {
    test('401s when no Authorization header is present', () async {
      final response = await call('/api/v1/checkout/exchange', method: 'POST');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {'error': 'CHECKOUT_TOKEN_REQUIRED'});
    });

    test('401s for a forged checkout token', () async {
      final response = await exchange('not-a-real-token');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {'error': 'CHECKOUT_TOKEN_INVALID'});
    });

    test('returns an allowed-host checkoutUrl', () async {
      final result = await freshCheckout();
      final checkoutUrl = Uri.parse(result.exchanged['checkoutUrl']! as String);
      expect(checkoutUrl.scheme, 'https');
      expect(checkoutUrl.host, 'pay.sandbox.travelpay.com.au');
      expect(result.exchanged.containsKey('merchantUniquePaymentId'), isFalse);
    });

    test(
      'replaying the same checkout token resolves to the same attempt, not a new one',
      () async {
        final first = await freshCheckout(
          idempotencyKey: 'idempotency-key-replay',
        );
        final secondExchange = await exchange(first.checkoutToken);
        final second = jsonDecode(secondExchange.body) as Map<String, Object?>;

        expect(secondExchange.statusCode, 200);
        expect(second['checkoutUrl'], first.exchanged['checkoutUrl']);
      },
    );
  });

  group('GET /api/v1/sessions', () {
    test(
      'returns the stored attempt state for a valid token, with no identifiers',
      () async {
        store.create(_attempt());
        final token = _token(merchantUniquePaymentId: 'att-lookup');

        final response = await call('/api/v1/sessions?t=$token');
        expect(response.statusCode, 200);
        final json = jsonDecode(response.body) as Map<String, Object?>;
        expect(json.containsKey('attemptId'), isFalse);
        expect(json.containsKey('sessionId'), isFalse);
        expect(json.containsKey('merchantUniquePaymentId'), isFalse);
        expect(json['status'], 'created');
        expect(json['callbackVerified'], false);
        expect(json['callbackPayload'], isNull);
      },
    );

    test('401s for a missing token', () async {
      final response = await call('/api/v1/sessions');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {'error': 'TOKEN_REQUIRED'});
    });

    test('401s for a forged token', () async {
      final response = await call('/api/v1/sessions?t=not-a-real-token');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {'error': 'TOKEN_INVALID'});
    });

    test('404s for a token naming an unknown attempt', () async {
      final token = _token(merchantUniquePaymentId: 'no-such-attempt');
      final response = await call('/api/v1/sessions?t=$token');
      expect(response.statusCode, 404);
      expect(jsonDecode(response.body), {'error': 'CHECKOUT_NOT_FOUND'});
    });
  });

  group('POST /api/v1/callbacks', () {
    test('accepts a correctly signed callback and updates status', () async {
      store.create(
        _attempt(merchantUniquePaymentId: 'att-cb-1', amount: 25.50),
      );
      final digest = _sign(0, '2550', 'att-cb-1', 'PAY-1');

      final response = await call(
        '/api/v1/callbacks',
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: {
          'response': {
            'merchantUniquePaymentId': 'att-cb-1',
            'paymentReference': 'PAY-1',
            'paymentStatus': 3,
          },
          'validationCode': digest,
        },
      );
      expect(response.statusCode, 200);

      final token = _token(merchantUniquePaymentId: 'att-cb-1');
      final status = await call('/api/v1/sessions?t=$token');
      final body = jsonDecode(status.body) as Map<String, Object?>;
      expect(body['paymentReference'], 'PAY-1');
      expect(body['callbackVerified'], true);
      expect(body['status'], 'successful');
      final callbackPayload = body['callbackPayload']! as Map<String, Object?>;
      expect(callbackPayload['validationCode'], digest);
      final callbackResponse = callbackPayload['response']! as Map<String, Object?>;
      expect(callbackResponse['paymentReference'], 'PAY-1');
    });

    test('rejects a tampered ValidationCode', () async {
      store.create(
        _attempt(merchantUniquePaymentId: 'att-cb-2', amount: 25.50),
      );
      // Correctly shaped (128-char hex) but signed for a different
      // reference, so it fails the hash check rather than shape validation.
      final wrongDigest = _sign(0, '2550', 'att-cb-2', 'PAY-WRONG');

      final response = await call(
        '/api/v1/callbacks',
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: {
          'response': {
            'merchantUniquePaymentId': 'att-cb-2',
            'paymentReference': 'PAY-2',
            'paymentStatus': 3,
          },
          'validationCode': wrongDigest,
        },
      );
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {
        'error': 'CALLBACK_VALIDATION_FAILED',
      });

      final token = _token(merchantUniquePaymentId: 'att-cb-2');
      final status = await call('/api/v1/sessions?t=$token');
      final body = jsonDecode(status.body) as Map<String, Object?>;
      expect(body['callbackVerified'], false);
    });

    test('404s for an unknown attempt', () async {
      final response = await call(
        '/api/v1/callbacks',
        method: 'POST',
        headers: {'content-type': 'application/json'},
        body: {
          'response': {'merchantUniquePaymentId': 'no-such-payment'},
        },
      );
      expect(response.statusCode, 404);
      expect(jsonDecode(response.body), {
        'error': 'CALLBACK_ATTEMPT_NOT_FOUND',
      });
    });
  });

  group('GET /return', () {
    test('redirects a mobile attempt to the app-return App Link', () async {
      store.create(
        _attempt(
          merchantUniquePaymentId: 'att-return-mobile',
        ),
      );
      final token = _token(merchantUniquePaymentId: 'att-return-mobile');
      final request = http.Request('GET', Uri.parse('$base/return?t=$token'))..followRedirects = false;
      final response = await http.Response.fromStream(await request.send());
      expect(response.statusCode, 303);
      expect(response.headers['location'], contains('/zenpay/app-return'));
      expect(response.headers['location'], contains('t=$token'));
    });

    test(
      'redirects a web attempt to the configured web return origin',
      () async {
        store.create(
          _attempt(
            merchantUniquePaymentId: 'att-return-web',
            client: CheckoutClient.web,
          ),
        );
        final token = _token(merchantUniquePaymentId: 'att-return-web');
        final request = http.Request('GET', Uri.parse('$base/return?t=$token'))..followRedirects = false;
        final response = await http.Response.fromStream(await request.send());
        expect(response.statusCode, 303);
        expect(
          response.headers['location'],
          startsWith('https://localhost:3000/'),
        );
      },
    );

    test('401s for a missing token', () async {
      final response = await call('/return');
      expect(response.statusCode, 401);
      expect(jsonDecode(response.body), {'error': 'TOKEN_REQUIRED'});
    });

    test('400s for a token naming an unknown attempt', () async {
      final token = _token(merchantUniquePaymentId: 'unknown');
      final response = await call('/return?t=$token');
      expect(response.statusCode, 400);
      expect(jsonDecode(response.body), {
        'error': 'RETURN_TOKEN_UNKNOWN_ATTEMPT',
      });
    });
  });

  group('Firebase App Check enforcement', () {
    test(
      'rejects POST /api/v1/checkout/token with 401 when header is missing',
      () async {
        await server.close(force: true);
        final verifier = _FakeAppCheckVerifier();
        await startServer(
          _config(firebaseProjectNumber: '123456789'),
          appCheckVerifier: verifier,
        );

        final response = await prepare(
          idempotencyKey: 'idempotency-key-appcheck-missing',
        );

        expect(response.statusCode, 401);
        expect(jsonDecode(response.body), {'error': 'APP_CHECK_TOKEN_MISSING'});
      },
    );

    test(
      'rejects POST /api/v1/checkout/token with 401 when token is invalid',
      () async {
        await server.close(force: true);
        final verifier = _FakeAppCheckVerifier(shouldPass: false);
        await startServer(
          _config(firebaseProjectNumber: '123456789'),
          appCheckVerifier: verifier,
        );

        final response = await call(
          '/api/v1/checkout/token',
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'idempotency-key': 'idempotency-key-appcheck-invalid',
            'x-client': 'web',
            'x-firebase-appcheck': 'invalid-token',
          },
          body: _prepareBody(),
        );

        expect(response.statusCode, 401);
        expect(jsonDecode(response.body), {'error': 'APP_CHECK_INVALID'});
      },
    );

    test(
      'accepts POST /api/v1/checkout/token with 201 when token is valid',
      () async {
        await server.close(force: true);
        final verifier = _FakeAppCheckVerifier();
        await startServer(
          _config(firebaseProjectNumber: '123456789'),
          appCheckVerifier: verifier,
        );

        final response = await call(
          '/api/v1/checkout/token',
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'idempotency-key': 'idempotency-key-appcheck-valid',
            'x-client': 'web',
            'x-firebase-appcheck': 'valid-token',
          },
          body: _prepareBody(),
        );

        expect(response.statusCode, 201);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['checkoutToken'], isNotNull);
      },
    );

    test(
      'bypasses App Check when firebaseProjectNumber is unconfigured',
      () async {
        await server.close(force: true);
        final verifier = _FakeAppCheckVerifier(shouldPass: false);
        await startServer(
          _config(),
          appCheckVerifier: verifier,
        );

        final response = await prepare(
          idempotencyKey: 'idempotency-key-appcheck-bypassed',
        );

        expect(response.statusCode, 201);
        final decoded = jsonDecode(response.body) as Map<String, Object?>;
        expect(decoded['checkoutToken'], isNotNull);
      },
    );
  });

  group('http_trace header redaction', () {
    test(
      'masks only authorization and x-firebase-appcheck in logged headers',
      () async {
        final records = <LogRecord>[];
        final subscription = Logger.root.onRecord.listen(records.add);

        final response = await call(
          '/api/v1/checkout/exchange',
          method: 'POST',
          headers: {
            'authorization': 'Bearer super-secret-checkout-token',
            'x-firebase-appcheck': 'app-check-jwt-secret-value',
            'x-request-id': 'trace-me-123',
          },
        );
        expect(response.statusCode, 401);

        await subscription.cancel();
        final traces = records.map((r) => r.message).where((m) => m.contains('http_trace')).toList();
        final exchangeTrace = traces.singleWhere(
          (m) => (jsonDecode(m) as Map<String, Object?>)['path'] == '/api/v1/checkout/exchange',
        );
        final headers = (jsonDecode(exchangeTrace) as Map<String, Object?>)['requestHeaders']! as Map<String, Object?>;

        expect(headers['authorization'], 'Bea...ken');
        expect(headers['x-firebase-appcheck'], 'app...lue');
        expect(headers['x-request-id'], 'trace-me-123');
      },
    );

    test('masks checkoutToken in logged response bodies', () async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);

      final response = await prepare(
        idempotencyKey: 'idempotency-key-redaction-body',
      );
      expect(response.statusCode, 201);
      final token = (jsonDecode(response.body) as Map<String, Object?>)['checkoutToken']! as String;

      await subscription.cancel();
      final traces = records.map((r) => r.message).where((m) => m.contains('http_trace')).toList();
      final tokenTrace = traces.singleWhere(
        (m) => (jsonDecode(m) as Map<String, Object?>)['path'] == '/api/v1/checkout/token',
      );
      final body = (jsonDecode(tokenTrace) as Map<String, Object?>)['responseBody']! as Map<String, Object?>;

      expect(
        body['checkoutToken'],
        '${token.substring(0, 3)}...${token.substring(token.length - 3)}',
      );
      expect(body['checkoutToken'], isNot(token));
    });

    test('masks token and zp_session cookies, leaves other cookies as-is', () async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);

      final response = await call(
        '/api/v1/checkout/exchange',
        method: 'POST',
        headers: {
          'cookie': 'zp.last_used_login_method=email; zp_session=super-secret-session-value; token=super-secret-token-value',
        },
      );
      expect(response.statusCode, 401);

      await subscription.cancel();
      final traces = records.map((r) => r.message).where((m) => m.contains('http_trace')).toList();
      final exchangeTrace = traces.singleWhere(
        (m) => (jsonDecode(m) as Map<String, Object?>)['path'] == '/api/v1/checkout/exchange',
      );
      final headers = (jsonDecode(exchangeTrace) as Map<String, Object?>)['requestHeaders']! as Map<String, Object?>;

      expect(
        headers['cookie'],
        'zp.last_used_login_method=email; zp_session=sup...lue; token=sup...lue',
      );
    });
  });
}
