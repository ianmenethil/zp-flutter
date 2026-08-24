// Examples print their output so the flow is visible when run.
// ignore_for_file: avoid_print

/// End-to-end server-side ZenPay Hosted Checkout flow: mint the launch
/// fingerprint, build the Authorise URL, then authenticate the callback
/// ZenPay posts back.
///
/// Run with `dart run example/main.dart`, optionally supplying real sandbox
/// credentials through the environment:
///
/// ```bash
/// ZP_API_KEY=... ZP_USERNAME=... ZP_PASSWORD=... dart run example/main.dart
/// ```
library;

import 'dart:io';

import 'package:zenpay_dart/zenpay_dart.dart';

// Read from the environment, never hardcoded in source. The merchant password
// is the only genuine secret here — it is a hash input and never appears in
// the launch URL. The fallbacks are inert stand-ins so the example still runs
// unconfigured; do not replace them with real values.
final String _apiKey = Platform.environment['ZP_API_KEY'] ?? 'unset-api-key';
final String _username = Platform.environment['ZP_USERNAME'] ?? 'unset-username';
final String _password = Platform.environment['ZP_PASSWORD'] ?? 'unset-password';
final String _merchantCode = Platform.environment['ZP_MERCHANT_CODE'] ?? 'ZenTest1';
final String _endpoint = Platform.environment['ZP_ENDPOINT'] ?? 'https://pay.sandbox.b2bpay.com.au/Online/v5';

void main() {
  // One timestamp and one MUPID per payment attempt. Both feed the
  // fingerprint hash, so reuse the same values for the URL you build from it.
  final timestamp = createZpTimestamp();
  final mupid = createZpMupid();
  const amount = '49.90';

  // 1. Fingerprint — SHA3-512 over the seven pipe-delimited hash fields.
  final fingerprint = createZpFingerprint(
    ZpFingerprintInput(
      apiKey: _apiKey,
      username: _username,
      password: _password,
      mode: ZpPluginMode.makePayment,
      paymentAmount: amount,
      merchantUniquePaymentId: mupid,
      timestamp: timestamp,
    ),
  );

  final String digest;
  switch (fingerprint) {
    case ZpFingerprintSuccess(:final fingerprint):
      digest = fingerprint;
      print('fingerprint: ${fingerprint.substring(0, 16)}...');
    case ZpFingerprintFailure(:final message):
      print('fingerprint failed: $message');

      return;
  }

  // 2. Authorise URL — built locally, no network call.
  final url = createZpCheckoutUrl(
    ZpCheckoutOptions(
      url: _endpoint,
      apiKey: _apiKey,
      fingerprint: digest,
      merchantCode: _merchantCode,
      timestamp: timestamp,
      merchantUniquePaymentId: mupid,
      customerEmail: 'jane@example.com',
      paymentAmount: amount,
      customerName: 'Jane Smith',
      customerReference: 'ORD-1001',
      redirectUrl: 'https://merchant.example/return',
    ),
  );

  switch (url) {
    case ZpUrlSuccess(:final url):
      // Safe to log in full: the launch URL carries only public values
      // (__ApiKey, __Fingerprint, merchantCode) — the customer's browser
      // loads this exact URL. The merchant password never appears in it.
      print('launch URL: $url');
    case ZpUrlFailure(:final message):
      print('url failed: $message');

      return;
  }

  // 3. Callback verification — the only trustworthy confirmation of payment.
  // A browser redirect or a dismissed checkout is provisional; this is not.
  // `body` here stands in for the JSON ZenPay POSTs to your callbackUrl.
  // `validationCode` sits at the top level, alongside `response`. The value
  // here is a well-formed but deliberately wrong 128-hex digest, so this
  // example demonstrates the rejection path rather than faking a valid hash.
  final body = <String, Object?>{
    'response': <String, Object?>{
      'merchantUniquePaymentId': mupid.value,
      'paymentReference': 'PAY-9001',
      'paymentStatus': ZpPaymentStatus.successful.wireValue,
    },
    'validationCode': '0'.padLeft(128, '0'),
  };

  final callback = verifyZpCallback(
    ZpPluginMode.makePayment,
    body,
    ZpVerifyCallbackContext(
      apiKey: _apiKey,
      username: _username,
      password: _password,
      paymentAmount: amount,
      merchantUniquePaymentId: mupid,
    ),
  );

  // Never throws — every failure comes back as a result to switch on.
  switch (callback) {
    case ZpCallbackVerified():
      print('callback authentic — settle the order');
    case ZpCallbackMalformed(:final message):
      print('callback malformed (respond 400): $message');
    case ZpCallbackRejected(:final message):
      print('callback rejected (respond 401): $message');
  }
}
