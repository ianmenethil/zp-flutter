/// The backend calls the demo makes, per `backend/lib/src/server_app.dart`:
/// a two-step checkout (prepare a signed capability, exchange it for a
/// checkout URL) and status polling.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

const _checkoutTokenEndpoint = '/api/v1/checkout/token';
const _checkoutExchangeEndpoint = '/api/v1/checkout/exchange';
const _sessionsEndpoint = '/api/v1/sessions';
const _headerContentType = 'content-type';
const _headerIdempotencyKey = 'idempotency-key';
const _headerAuthorization = 'authorization';
const _headerAppCheck = 'x-firebase-appcheck';
const _contentTypeJson = 'application/json';
const _clientWeb = 'web';
const _clientMobile = 'mobile';
const _idempotencyPrefix = 'demo';

// Bound for the random suffix. NOT `1 << 32`: on web an int is a JS number and
// bitwise ops are 32-bit, so that expression wraps to 0 and nextInt throws
// "max must be in range 0 < max <= 2^32, was 0".
const _idempotencySaltMax = 0xFFFFFFF;
const _errorKey = 'error';

/// A non-success response, carrying the backend's machine-readable error code.
final class BackendError implements Exception {
  /// Creates a [BackendError].
  const BackendError(this.statusCode, this.code);

  /// HTTP status returned.
  final int statusCode;

  /// Backend error code, when the body carried one.
  final String? code;

  @override
  String toString() => 'Backend $statusCode${code == null ? '' : ' ($code)'}';
}

/// Response body from `POST /api/v1/checkout/exchange`.
class ExchangeResponse {
  /// Creates an [ExchangeResponse].
  const ExchangeResponse({required this.checkoutUrl});

  /// Decodes an [ExchangeResponse] from the backend's JSON body.
  factory ExchangeResponse.fromJson(Map<String, Object?> json) => ExchangeResponse(checkoutUrl: json['checkoutUrl']! as String);

  /// The ZenPay HCP launch URL to present to the customer.
  final String checkoutUrl;
}

/// Response body from `GET /api/v1/sessions` — the backend's authoritative
/// status for one attempt.
class StatusResponse {
  /// Creates a [StatusResponse].
  const StatusResponse({
    required this.status,
    required this.callbackVerified,
    this.paymentReference,
    this.preauthReference,
    this.tokenReference,
    this.failureCode,
    this.failureReason,
    this.zenPayStatusCode,
    this.callbackPayload,
  });

  /// Decodes a [StatusResponse] from the backend's JSON body.
  factory StatusResponse.fromJson(Map<String, Object?> json) => StatusResponse(
    status: json['status']! as String,
    callbackVerified: json['callbackVerified']! as bool,
    paymentReference: json['paymentReference'] as String?,
    preauthReference: json['preauthReference'] as String?,
    tokenReference: json['tokenReference'] as String?,
    failureCode: json['failureCode'] as String?,
    failureReason: json['failureReason'] as String?,
    zenPayStatusCode: json['zenPayStatusCode'] as int?,
    callbackPayload: json['callbackPayload'] as Map<String, Object?>?,
  );

  /// Merchant-facing lifecycle status name (e.g. `'successful'`, `'pending'`).
  final String status;

  /// Whether ZenPay's signed server-to-server callback has verified this
  /// attempt — a bare return does not.
  final bool callbackVerified;

  /// Verified payment reference (modes 0/2 only).
  final String? paymentReference;

  /// Verified pre-authorization reference (mode 3 only).
  final String? preauthReference;

  /// Verified token reference (mode 1 only).
  final String? tokenReference;

  /// Failure code from the verified callback, if any.
  final String? failureCode;

  /// Failure reason from the verified callback, if any.
  final String? failureReason;

  /// Raw ZenPay wire status code from the verified callback, if any.
  final int? zenPayStatusCode;

  /// The entire verified callback body ZenPay posted —
  /// `{response, validationCode}` — unfiltered, if any.
  final Map<String, Object?>? callbackPayload;
}

/// A fresh `idempotency-key` header value.
String _idempotencyKey() => '$_idempotencyPrefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(_idempotencySaltMax)}';

/// Step 1 — prepares a checkout and returns a signed, short-lived checkout
/// token. [fields] is the order/customer data; `client` is set automatically.
///
/// [client] overrides the HTTP client, so tests can inject a
/// `package:http/testing.dart` [MockClient]; a null client owns and closes its
/// own, like the top-level `http.post` helper.
///
/// [appCheckToken] attaches the `X-Firebase-AppCheck` header for backend
/// attestation verification when configured.
Future<String> prepareCheckout(
  Uri baseUrl,
  Map<String, Object?> fields, {
  http.Client? client,
  String? appCheckToken,
}) async {
  final json = _body(
    await _request(
      client,
      (c) => c.post(
        baseUrl.resolve(_checkoutTokenEndpoint),
        headers: <String, String>{
          _headerContentType: _contentTypeJson,
          _headerIdempotencyKey: _idempotencyKey(),
          _headerAppCheck: ?appCheckToken,
        },
        // Only 'web' and 'mobile' are accepted; iframe checkout is disabled
        // project-wide (`backend/lib/src/models.dart`).
        body: jsonEncode(<String, Object?>{
          ...fields,
          'client': kIsWeb ? _clientWeb : _clientMobile,
        }),
      ),
    ),
    201,
  );
  return json['checkoutToken']! as String;
}

/// Step 2 — exchanges [checkoutToken] for a checkout URL. Safe to call more
/// than once with the same token: it always resolves to the same attempt,
/// never a new one.
Future<ExchangeResponse> exchangeCheckout(
  Uri baseUrl,
  String checkoutToken, {
  http.Client? client,
}) async => ExchangeResponse.fromJson(
  _body(
    await _request(
      client,
      (c) => c.post(
        baseUrl.resolve(_checkoutExchangeEndpoint),
        headers: <String, String>{
          _headerAuthorization: 'Bearer $checkoutToken',
        },
      ),
    ),
    200,
  ),
);

/// The backend's authoritative status — a return URI proves return, not
/// payment. [token] is the signed `t` value the return URI carried.
///
/// [client] overrides the HTTP client for tests, as in [prepareCheckout].
Future<StatusResponse> fetchStatus(
  Uri baseUrl,
  String token, {
  http.Client? client,
}) async => StatusResponse.fromJson(
  _body(
    await _request(
      client,
      (c) => c.get(
        baseUrl.resolve(_sessionsEndpoint).replace(queryParameters: {'t': token}),
      ),
    ),
    200,
  ),
);

/// Runs [call] through [client], or through a client owned and closed here
/// when [client] is null — mirroring the top-level `http` helpers' lifecycle.
Future<http.Response> _request(
  http.Client? client,
  Future<http.Response> Function(http.Client) call,
) async {
  if (client != null) {
    return call(client);
  }

  final owned = http.Client();
  try {
    return await call(owned);
  } finally {
    owned.close();
  }
}

/// Decodes [response], throwing [BackendError] unless it matches [expected].
Map<String, Object?> _body(http.Response response, int expected) {
  final decoded = response.body.isEmpty ? const <String, Object?>{} : jsonDecode(response.body) as Map<String, Object?>;
  if (response.statusCode != expected) {
    throw BackendError(response.statusCode, decoded[_errorKey] as String?);
  }

  return decoded;
}
