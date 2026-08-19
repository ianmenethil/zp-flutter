/// The example backend's HTTP surface: health, two-step checkout creation,
/// status lookup, callback verification, and browser return.
///
/// This is a minimal demo backend, not a hardened one — see
/// `CLAUDE.md` § 1 for what "minimal" means here and why. The anonymous
/// checkout-creation boundary (`/checkout/token`, `/checkout/exchange`) is
/// rate-limited per IP; it is not authenticated, because there is no
/// merchant login in this demo — see `session_service.dart`'s doc comment.
///
/// Mobile app attestation hook: verifies Firebase App Check (wrapping Apple
/// App Attest / Android Play Integrity / Web reCAPTCHA) as an admission check
/// inside [_handleCreateCheckoutToken] before [prepareCheckout] runs. Enabled
/// when `FIREBASE_PROJECT_NUMBER` is configured.
library;

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:zenpay_dart/zenpay_dart.dart'
    show
        ZpCallbackUrlTokenFailure,
        ZpCallbackUrlTokenPayload,
        ZpCallbackUrlTokenVerified,
        createZpMupid,
        verifyZpCallbackUrlToken;

import 'app_check.dart' show AppCheckVerifier, FirebaseAppCheckVerifier;
import 'attempt_store.dart';
import 'config.dart';
import 'models.dart';
import 'rate_limiter.dart' show FixedWindowRateLimiter;
import 'security.dart' show constantTimeEqual, verifyCallback;
import 'session_service.dart'
    show
        appReturnUriFor,
        callbacksPath,
        exchangeCheckout,
        prepareCheckout,
        returnPath;
import 'token_keys.dart' show callbackTokenKey;

/// HTTP header name constants used across request parsing and logging.
abstract final class _HeaderNames {
  static const authorization = 'authorization';
  static const contentType = 'content-type';
  static const idempotencyKey = 'idempotency-key';
  static const xForwardedFor = 'x-forwarded-for';
  static const userAgent = 'user-agent';
  static const xFirebaseAppCheck = 'x-firebase-appcheck';
}

/// Extracts the client IP from `X-Forwarded-For`, falling back to the raw
/// socket's remote address.
String _clientIp(shelf.Request request) {
  final forwardedFor = request.headers[_HeaderNames.xForwardedFor];
  final rawIp = forwardedFor?.split(',').first.trim();
  if (rawIp != null && rawIp.isNotEmpty) return rawIp;
  final connectionInfo =
      request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
  return connectionInfo?.remoteAddress.address ?? 'unknown';
}

/// Reads and parses a JSON request body with a 64KB maximum size limit.
Future<Map<String, Object?>> _readJson(shelf.Request request) async {
  final contentType = request.headers[_HeaderNames.contentType];
  if (contentType == null ||
      !contentType.toLowerCase().startsWith('application/json')) {
    throw HttpError(415, 'APPLICATION_JSON_REQUIRED');
  }

  final chunks = <int>[];
  var tooLarge = false;
  // Drain the full stream even once over-limit, so the client's upload
  // completes instead of the connection being torn down mid-write.
  await for (final chunk in request.read()) {
    if (!tooLarge) {
      chunks.addAll(chunk);
      tooLarge = chunks.length > 64 * 1024;
    }
  }
  if (tooLarge) throw HttpError(413, 'REQUEST_BODY_TOO_LARGE');
  if (chunks.isEmpty) throw HttpError(400, 'REQUEST_BODY_REQUIRED');

  Object? parsed;
  try {
    parsed = jsonDecode(utf8.decode(chunks));
  } on FormatException {
    throw HttpError(400, 'INVALID_JSON');
  }
  if (parsed is! Map<String, Object?>) throw HttpError(400, 'INVALID_JSON');
  return parsed;
}

/// Extracts a bearer token from `Authorization`, or throws [HttpError] `401`
/// with [missingCode] if it is absent or malformed.
String _requireBearerToken(shelf.Request request, String missingCode) {
  const prefix = 'Bearer ';
  final header = request.headers[_HeaderNames.authorization];
  if (header == null || !header.startsWith(prefix)) {
    throw HttpError(401, missingCode);
  }
  final token = header.substring(prefix.length).trim();
  if (token.isEmpty) throw HttpError(401, missingCode);
  return token;
}

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Validates and parses a `POST /api/v1/checkout/token` request body.
PrepareCheckoutBody _parsePrepareCheckoutBody(Map<String, Object?> value) {
  final customerName = value['customerName'];
  if (customerName is! String ||
      customerName.trim().isEmpty ||
      customerName.trim().length > 250) {
    throw HttpError(400, 'INVALID_CHECKOUT_NAME');
  }
  final customerEmail = value['customerEmail'];
  if (customerEmail is! String ||
      customerEmail.trim().isEmpty ||
      customerEmail.trim().length > 254 ||
      !_emailPattern.hasMatch(customerEmail.trim())) {
    throw HttpError(400, 'INVALID_CHECKOUT_EMAIL');
  }
  final modeRaw = value['mode'];
  if (modeRaw != null && (modeRaw is! int || modeRaw < 0 || modeRaw > 3)) {
    throw HttpError(400, 'INVALID_CHECKOUT_MODE');
  }
  final client = switch (value['client']) {
    final String c => CheckoutClient.tryParse(c),
    _ => null,
  };
  if (client == null) throw HttpError(400, 'INVALID_CHECKOUT_CLIENT');
  final paymentAmountRaw = value['paymentAmount'];
  if (paymentAmountRaw != null && paymentAmountRaw is! num) {
    throw HttpError(400, 'INVALID_CHECKOUT_AMOUNT');
  }
  final customerReferenceRaw = value['customerReference'];
  if (customerReferenceRaw != null &&
      (customerReferenceRaw is! String ||
          customerReferenceRaw.trim().isEmpty ||
          customerReferenceRaw.trim().length > 128)) {
    throw HttpError(400, 'INVALID_CHECKOUT_REFERENCE');
  }
  // ZenPay's own Authorise validation requires customerReference (with
  // customerName, already required above) for Make Payment and Custom
  // Payment — see `checkout_url.dart`'s `requiresCustomer`.
  final effectiveMode = (modeRaw as int?) ?? 0;
  if ((effectiveMode == 0 || effectiveMode == 2) &&
      (customerReferenceRaw == null ||
          (customerReferenceRaw as String).trim().isEmpty)) {
    throw HttpError(400, 'CUSTOMER_REFERENCE_REQUIRED');
  }
  final contactNumberRaw = value['contactNumber'];
  if (contactNumberRaw != null &&
      (contactNumberRaw is! String ||
          contactNumberRaw.trim().isEmpty ||
          contactNumberRaw.trim().length > 32)) {
    throw HttpError(400, 'INVALID_CHECKOUT_CONTACT_NUMBER');
  }

  return PrepareCheckoutBody(
    customerName: customerName.trim(),
    customerEmail: customerEmail.trim(),
    client: client,
    mode: modeRaw,
    paymentAmount: paymentAmountRaw as num?,
    customerReference: (customerReferenceRaw as String?)?.trim(),
    contactNumber: (contactNumberRaw as String?)?.trim(),
  );
}

/// Builds a JSON response with security headers (`nosniff`, `no-store`,
/// a locked-down CSP) and an optional CORS allow-origin header.
shelf.Response _json(int status, Object? body, {String? allowedOrigin}) {
  final headers = {
    _HeaderNames.contentType: 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    'referrer-policy': 'no-referrer',
    'content-security-policy': "default-src 'none'",
  };
  if (allowedOrigin != null) {
    headers['access-control-allow-origin'] = allowedOrigin;
    headers['vary'] = 'origin';
  }
  return shelf.Response(status, body: jsonEncode(body), headers: headers);
}

/// Builds a `303 See Other` redirect to [location], used for the browser
/// return flow.
shelf.Response _redirect(Uri location) => shelf.Response(
  303,
  headers: {
    'location': location.toString(),
    'cache-control': 'no-store',
    'referrer-policy': 'no-referrer',
  },
);

/// Handles `GET /api/v1/health` — reports whether required ZenPay
/// configuration is present for session creation and callback verification.
shelf.Response _handleHealth(AppConfig config) {
  final missingSession = sessionConfigurationErrors(config);
  final missingCallback = callbackConfigurationErrors(config);
  return _json(200, {
    'ok': true,
    'sessionReady': missingSession.isEmpty,
    'callbackReady': missingCallback.isEmpty,
    'missingSessionConfiguration': missingSession,
    'missingCallbackConfiguration': missingCallback,
  });
}

/// Throws [HttpError] `429` and logs `checkout.rate_limited` if [limiter]
/// rejects [request]'s client IP.
void _requireRateLimit(
  shelf.Request request,
  FixedWindowRateLimiter limiter,
  String route,
) {
  if (limiter.allow(_clientIp(request))) return;
  _recordEvent(request, 'checkout.rate_limited', {'route': route});
  throw HttpError(429, 'RATE_LIMITED');
}

/// Handles `POST /api/v1/checkout/token` — Step 1 of checkout creation.
/// Validates the request, requires an `Idempotency-Key` header, resolves the
/// trusted amount, and returns a signed checkout token. This is the
/// anonymous admission boundary — see this file's doc comment.
Future<shelf.Response> _handleCreateCheckoutToken(
  shelf.Request request,
  AppConfig config,
  AttemptStore store,
  FixedWindowRateLimiter limiter,
  AppCheckVerifier? appCheckVerifier,
) async {
  _requireRateLimit(request, limiter, 'checkout/token');

  final missing = sessionConfigurationErrors(config);
  if (missing.isNotEmpty) {
    throw HttpError(503, 'SESSION_CONFIGURATION_REQUIRED:${missing.join(',')}');
  }

  if (appCheckVerifier != null && config.firebaseProjectNumber.isNotEmpty) {
    final appCheckToken = request.headers[_HeaderNames.xFirebaseAppCheck];
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw HttpError(401, 'APP_CHECK_TOKEN_MISSING');
    }
    final valid = await appCheckVerifier.verify(
      appCheckToken,
      config.firebaseProjectNumber,
    );
    if (!valid) {
      throw HttpError(401, 'APP_CHECK_INVALID');
    }
  }

  final idempotencyKey = request.headers[_HeaderNames.idempotencyKey];
  if (idempotencyKey == null ||
      idempotencyKey.length < 16 ||
      idempotencyKey.length > 128) {
    throw HttpError(400, 'INVALID_IDEMPOTENCY_KEY');
  }

  final rawBody = await _readJson(request);
  final body = _parsePrepareCheckoutBody(rawBody);
  final isReplay = store.getByIdempotencyKey(idempotencyKey) != null;

  final checkoutToken = prepareCheckout(body, idempotencyKey, config, store);
  if (!isReplay) {
    _recordEvent(request, 'checkout.attempt_created', {'mode': body.mode ?? 0});
  }

  return _json(201, {
    'checkoutToken': checkoutToken,
  }, allowedOrigin: config.allowedAppOrigin);
}

/// Handles `POST /api/v1/checkout/exchange` — Step 2 of checkout creation.
/// Verifies the checkout token from `Authorization: Bearer`, and builds
/// (or, on replay, reuses) the ZenPay checkout URL.
Future<shelf.Response> _handleExchangeCheckout(
  shelf.Request request,
  AppConfig config,
  AttemptStore store,
  FixedWindowRateLimiter limiter,
) async {
  _requireRateLimit(request, limiter, 'checkout/exchange');

  final missing = sessionConfigurationErrors(config);
  if (missing.isNotEmpty) {
    throw HttpError(503, 'SESSION_CONFIGURATION_REQUIRED:${missing.join(',')}');
  }

  final checkoutToken = _requireBearerToken(request, 'CHECKOUT_TOKEN_REQUIRED');
  final response = exchangeCheckout(checkoutToken, config, store);

  return _json(200, response.toJson(), allowedOrigin: config.allowedAppOrigin);
}

/// Verifies the `t` return/status token, returning its decoded payload.
///
/// This token is the only thing authorizing a status lookup or return —
/// nothing here trusts a caller-supplied id directly.
ZpCallbackUrlTokenPayload _requireToken(Uri requestedUri, AppConfig config) {
  final token = requestedUri.queryParameters['t'];
  if (token == null) throw HttpError(401, 'TOKEN_REQUIRED');

  return switch (verifyZpCallbackUrlToken(token, callbackTokenKey(config))) {
    ZpCallbackUrlTokenVerified(:final payload) => payload,
    ZpCallbackUrlTokenFailure() => throw HttpError(401, 'TOKEN_INVALID'),
  };
}

/// Handles `GET /api/v1/sessions` — returns the backend's authoritative
/// status for the checkout attempt named by the verified `t` token. No
/// identifier is echoed back — the caller already knows which attempt it
/// asked about via the token it presented.
shelf.Response _handleGetSession(
  Uri requestedUri,
  AppConfig config,
  AttemptStore store,
) {
  final payload = _requireToken(requestedUri, config);
  final attempt = store.getByMerchantPaymentId(payload.merchantUniquePaymentId);
  if (attempt == null) throw HttpError(404, 'CHECKOUT_NOT_FOUND');

  return _json(200, {
    'status': attempt.status.name,
    'paymentReference': attempt.paymentReference,
    'preauthReference': attempt.preauthReference,
    'tokenReference': attempt.tokenReference,
    'failureCode': attempt.failureCode,
    'failureReason': attempt.failureReason,
    'callbackVerified': attempt.verifiedCallbackReference != null,
    'zenPayStatusCode': attempt.verifiedCallbackStatusCode,
    'callbackPayload': attempt.verifiedCallbackPayload,
  }, allowedOrigin: config.allowedAppOrigin);
}

/// Handles `POST /api/v1/callbacks` — verifies the ZenPay `ValidationCode`
/// signature and applies the result to the matching stored attempt. This is
/// the sole authoritative source of payment status.
Future<shelf.Response> _handleCallback(
  shelf.Request request,
  AppConfig config,
  AttemptStore store,
  FixedWindowRateLimiter limiter,
) async {
  _requireRateLimit(request, limiter, 'callbacks');

  final missing = callbackConfigurationErrors(config);
  if (missing.isNotEmpty) {
    throw HttpError(
      503,
      'CALLBACK_CONFIGURATION_REQUIRED:${missing.join(',')}',
    );
  }

  final payload = await _readJson(request);
  final merchantUniquePaymentId = switch (payload['response']) {
    {'merchantUniquePaymentId': final String id} when id.isNotEmpty => id,
    _ => null,
  };
  if (merchantUniquePaymentId == null) {
    throw HttpError(400, 'CALLBACK_MERCHANT_PAYMENT_ID_REQUIRED');
  }

  final attempt = store.getByMerchantPaymentId(merchantUniquePaymentId);
  if (attempt == null) throw HttpError(404, 'CALLBACK_ATTEMPT_NOT_FOUND');

  final verification = verifyCallback(
    payload,
    attempt,
    config.zenPay.credentials,
  );
  if (!verification.ok) {
    _recordEvent(request, 'callback_rejected', {
      'merchantUniquePaymentId': merchantUniquePaymentId,
      'reason': verification.reason,
      'validationCode': payload['validationCode'],
    });
    final malformed = verification.reason == 'malformed';
    throw HttpError(
      malformed ? 400 : 401,
      malformed ? 'CALLBACK_BODY_INVALID' : 'CALLBACK_VALIDATION_FAILED',
    );
  }
  final fields = verification.fields!;
  final mappedStatus = mapZenPayStatus(fields.statusCode);
  _recordEvent(request, 'checkout.callback_verified', {
    'merchantUniquePaymentId': merchantUniquePaymentId,
    'validationCode': payload['validationCode'],
    'statusCode': fields.statusCode,
    'mappedStatus': mappedStatus.name,
    if (fields.failureCode != null) 'failureCode': fields.failureCode,
    if (fields.failureReason != null) 'failureReason': fields.failureReason,
  });

  if (attempt.verifiedCallbackReference != null &&
      (!constantTimeEqual(
            attempt.verifiedCallbackReference!,
            fields.reference,
          ) ||
          attempt.verifiedCallbackStatusCode != fields.statusCode)) {
    throw HttpError(409, 'CALLBACK_CONFLICT');
  }

  store.replace(
    attempt.merchantUniquePaymentId,
    attempt.copyWith(
      paymentReference: attempt.mode == 0 || attempt.mode == 2
          ? fields.reference
          : attempt.paymentReference,
      preauthReference: attempt.mode == 3
          ? fields.reference
          : attempt.preauthReference,
      tokenReference: attempt.mode == 1
          ? fields.reference
          : attempt.tokenReference,
      status: mappedStatus,
      failureCode: fields.failureCode,
      failureReason: fields.failureReason,
      verifiedCallbackReference: fields.reference,
      verifiedCallbackStatusCode: fields.statusCode,
      verifiedCallbackPayload: fields.rawPayload,
    ),
  );

  if (mappedStatus == MerchantPaymentStatus.successful) {
    _recordEvent(request, 'checkout.attempt_succeeded', {
      'merchantUniquePaymentId': merchantUniquePaymentId,
      'paymentReference': fields.reference,
    });
  } else if (mappedStatus == MerchantPaymentStatus.failed ||
      mappedStatus == MerchantPaymentStatus.cancelled ||
      mappedStatus == MerchantPaymentStatus.error) {
    _recordEvent(request, 'checkout.attempt_failed', {
      'merchantUniquePaymentId': merchantUniquePaymentId,
      if (fields.failureCode != null) 'failureCode': fields.failureCode,
      if (fields.failureReason != null) 'failureReason': fields.failureReason,
    });
  }

  return _json(200, {'ok': true});
}

/// Statuses a bare browser return must not downgrade — the callback (if it
/// already arrived) is authoritative over the return redirect.
const _terminalStatuses = {
  MerchantPaymentStatus.successful,
  MerchantPaymentStatus.failed,
  MerchantPaymentStatus.cancelled,
  MerchantPaymentStatus.error,
};

/// Handles `GET /return` — the browser landing page after ZenPay redirects
/// back. Marks the attempt as browser-returned (provisional, not
/// callback-verified) and forwards to the app/web return destination.
shelf.Response _handleReturn(
  Uri requestedUri,
  AppConfig config,
  AttemptStore store,
) {
  final payload = _requireToken(requestedUri, config);

  final attempt = store.getByMerchantPaymentId(payload.merchantUniquePaymentId);
  if (attempt == null) {
    throw HttpError(400, 'RETURN_TOKEN_UNKNOWN_ATTEMPT');
  }

  store.replace(
    payload.merchantUniquePaymentId,
    attempt.copyWith(
      status: _terminalStatuses.contains(attempt.status)
          ? attempt.status
          : MerchantPaymentStatus.browserReturned,
    ),
  );

  final appReturn = appReturnUriFor(
    attempt,
    config,
  ).replace(queryParameters: {'t': requestedUri.queryParameters['t']!});
  return _redirect(appReturn);
}

/// Serves an App Link / Universal Link verification file from `well_known/`.
///
/// Android and iOS fetch these over the public internet at install time to
/// confirm this domain authorises the app to handle its checkout return links.
/// Without them `autoVerify` fails and the OS opens a browser instead of the
/// app. [name] is matched against a fixed set by the route, so it can never
/// traverse out of the directory.
Future<shelf.Response> _handleWellKnown(String name) async {
  final file = File('well_known/$name');
  if (!file.existsSync()) throw HttpError(404, 'NOT_FOUND');

  return shelf.Response.ok(
    await file.readAsString(),
    headers: {_HeaderNames.contentType: 'application/json'},
  );
}

/// Populated by [_buildRouter] as routes are registered — the single source
/// for [describeRoutes], so the startup log can't drift from what's actually
/// routed. `shelf_router.Router` keeps its own route list private with no
/// public getter, so there is no way to read this back off the router itself.
final _registeredRoutes = <({String method, String path})>[];

/// The server's route table, for startup logging — see [_registeredRoutes].
List<({String method, String path})> describeRoutes() =>
    List.unmodifiable(_registeredRoutes);

/// Builds the route table for all example backend endpoints.
///
/// Unmatched requests throw [HttpError] `404` rather than shelf_router's
/// default plain-text 404, so `buildHandler`'s catch clause still produces
/// the same JSON error shape as every other failure.
shelf_router.Router _buildRouter(
  AppConfig config,
  AttemptStore store,
  AppCheckVerifier? appCheckVerifier,
) {
  final checkoutLimiter = FixedWindowRateLimiter(
    config.checkoutRateLimitPerMinute,
    const Duration(seconds: 60),
  );
  // Higher ceiling than checkoutLimiter, deliberately: ZenPay retries
  // callbacks, so this must not reject a legitimate retry.
  final callbackLimiter = FixedWindowRateLimiter(
    240,
    const Duration(seconds: 60),
  );

  final router = shelf_router.Router(
    notFoundHandler: (shelf.Request request) =>
        throw HttpError(404, 'NOT_FOUND'),
  );

  void get(String path, Function handler) {
    router.get(path, handler);
    _registeredRoutes.add((method: 'GET', path: path));
  }

  void post(String path, Function handler) {
    router.post(path, handler);
    _registeredRoutes.add((method: 'POST', path: path));
  }

  get('/api/v1/health', (shelf.Request request) => _handleHealth(config));
  get(
    '/.well-known/assetlinks.json',
    (shelf.Request request) => _handleWellKnown('assetlinks.json'),
  );
  get(
    '/.well-known/apple-app-site-association',
    (shelf.Request request) => _handleWellKnown('apple-app-site-association'),
  );
  post(
    '/api/v1/checkout/token',
    (shelf.Request request) => _handleCreateCheckoutToken(
      request,
      config,
      store,
      checkoutLimiter,
      appCheckVerifier,
    ),
  );
  post(
    '/api/v1/checkout/exchange',
    (shelf.Request request) =>
        _handleExchangeCheckout(request, config, store, checkoutLimiter),
  );
  get(
    '/api/v1/sessions',
    (shelf.Request request) =>
        _handleGetSession(request.requestedUri, config, store),
  );
  post(
    callbacksPath,
    (shelf.Request request) =>
        _handleCallback(request, config, store, callbackLimiter),
  );
  get(
    returnPath,
    (shelf.Request request) =>
        _handleReturn(request.requestedUri, config, store),
  );

  return router;
}

/// Strips anything but a safe character set from an unexpected exception's
/// message before it's used as a logged error code.
final _sanitizePattern = RegExp(r'[^A-Za-z0-9_:.-]');

/// Builds the top-level Shelf handler serving all example backend routes.
shelf.Handler buildHandler(
  AppConfig config,
  AttemptStore store, {
  AppCheckVerifier? appCheckVerifier,
}) {
  final verifier =
      appCheckVerifier ??
      (config.firebaseServiceAccountJson.isNotEmpty
          ? FirebaseAppCheckVerifier(config.firebaseServiceAccountJson)
          : null);
  final router = _buildRouter(config, store, verifier);

  return (shelf.Request request) async {
    final startTime = DateTime.now();
    final clientIp = _clientIp(request);
    final requestId = createZpMupid().value;
    var withRequestId = request.change(
      context: {'requestId': requestId, 'events': <Map<String, Object?>>[]},
    );
    shelf.Response response;
    var requestBody = const <int>[];

    try {
      if (request.method == 'OPTIONS') {
        response = shelf.Response(
          204,
          headers: {
            'access-control-allow-origin': config.allowedAppOrigin,
            'access-control-allow-methods': 'GET,POST,OPTIONS',
            'access-control-allow-headers':
                'Content-Type,Idempotency-Key,Authorization',
          },
        );
      } else {
        // Buffered once here (rather than left as a single-read stream) so it
        // can be logged below and still reach the route handler's own
        // `_readJson` intact.
        requestBody = await withRequestId.read().expand((c) => c).toList();
        withRequestId = withRequestId.change(body: requestBody);
        response = await router(withRequestId);
      }
    } on HttpError catch (error) {
      _recordEvent(withRequestId, 'request_error', {'code': error.code});
      response = _json(error.statusCode, {'error': error.code});
    } catch (error) {
      final code = error.toString().replaceAll(_sanitizePattern, '_');
      _recordEvent(withRequestId, 'request_error', {'code': code});
      response = _json(500, {'error': code});
    }

    if (request.method != 'OPTIONS') {
      final responseBody = await response.read().expand((c) => c).toList();
      response = response.change(body: responseBody);

      // One record per request — everything about it in one place, instead
      // of a full raw trace and a separate curated summary that made it easy
      // to mistake one for the other. `events` carries whatever business
      // annotations (`_recordEvent`) fired along the way; empty on a plain
      // request nothing noteworthy happened to.
      final events =
          withRequestId.context['events']! as List<Map<String, Object?>>;
      String record() => _encoder.convert({
        'event': 'http_trace',
        'requestId': requestId,
        'ip': clientIp,
        'userAgent': request.headers[_HeaderNames.userAgent] ?? 'unknown',
        'method': request.method,
        'path': request.requestedUri.path,
        'requestHeaders': _redactHeaders(request.headers),
        'requestBody': _redactBody(
          utf8.decode(requestBody, allowMalformed: true),
        ),
        'status': response.statusCode,
        'responseHeaders': _redactHeaders(response.headers),
        'responseBody': _redactBody(
          utf8.decode(responseBody, allowMalformed: true),
        ),
        'durationMs': DateTime.now().difference(startTime).inMilliseconds,
        if (events.isNotEmpty) 'events': events,
      });
      if (response.statusCode >= 400) {
        _logger.warning(record);
      } else {
        _logger.info(record);
      }
    }
    return response;
  };
}

/// Appends [event] to the current request's accumulated event list, folded
/// into the one `http_trace` line [buildHandler] emits for that request once
/// it completes — see that function for why these aren't logged immediately.
void _recordEvent(
  shelf.Request request,
  String event, [
  Map<String, Object?> fields = const {},
]) {
  (request.context['events']! as List<Map<String, Object?>>).add({
    'event': event,
    ...fields,
  });
}

final _logger = Logger('zenpay_example_backend');
const _encoder = JsonEncoder.withIndent('  ');

// Headers/body fields never printed in full, regardless of log level — see
// README.md § Security Model, "No sensitive data in logs".
const _sensitiveHeaders = {'authorization', 'cookie', 'set-cookie'};
const _sensitiveBodyKeys = {'checkoutToken'};

Map<String, String> _redactHeaders(Map<String, String> headers) => {
  for (final entry in headers.entries)
    entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase())
        ? '[redacted]'
        : entry.value,
};

/// Best-effort JSON-decodes [raw] and masks known-sensitive top-level keys.
/// Falls back to the raw string for an empty or non-JSON body.
Object? _redactBody(String raw) {
  if (raw.isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return raw;
  }
  if (decoded is Map<String, Object?>) {
    return {
      for (final entry in decoded.entries)
        entry.key: _sensitiveBodyKeys.contains(entry.key)
            ? '[redacted]'
            : entry.value,
    };
  }
  return decoded;
}

void logEvent(
  String event, [
  Map<String, Object?> fields = const {},
  bool isError = false,
]) {
  final payload = _encoder.convert({'event': event, ...fields});
  if (isError) {
    _logger.warning(payload);
  } else {
    _logger.info(payload);
  }
}
