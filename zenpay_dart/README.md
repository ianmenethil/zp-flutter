# zenpay_dart

Pure-Dart server-side SDK for ZenPay Hosted Checkout: SHA3-512 fingerprint generation,
checkout launch-URL construction, and constant-time webhook callback verification.
Server-side only — never import this from a Flutter app; it handles merchant credentials.

## Getting started

```yaml
dependencies:
  zenpay_dart: ^0.1.0
```

## Usage

```dart
import 'package:zenpay_dart/zenpay_dart.dart';

final mupid = createZpMupid();
final timestamp = createZpTimestamp();

final fingerprintResult = createZpFingerprint(ZpFingerprintInput(
  apiKey: apiKey,
  username: username,
  password: password,
  mode: ZpPluginMode.makePayment,
  merchantUniquePaymentId: mupid,
  timestamp: timestamp,
  paymentAmount: 42.00,
));

final fingerprint = switch (fingerprintResult) {
  ZpFingerprintSuccess(:final fingerprint) => fingerprint,
  ZpFingerprintFailure(:final message) => throw StateError(message),
};

final urlResult = createZpCheckoutUrl(ZpCheckoutOptions(
  url: hppEndpointUrl,
  apiKey: apiKey,
  fingerprint: fingerprint,
  merchantCode: merchantCode,
  timestamp: timestamp,
  merchantUniquePaymentId: mupid,
  customerEmail: 'customer@example.com',
  paymentAmount: 42.00,
  callbackUrl: 'https://your-server.example/callbacks',
  redirectUrl: 'https://your-server.example/return',
));
```

On your webhook endpoint, `verifyZpCallback` is the only authoritative source of payment
status — a browser return or deep link is always provisional:

```dart
final result = verifyZpCallback(
  ZpPluginMode.makePayment,
  requestBody, // decoded JSON from ZenPay's POST
  ZpVerifyCallbackContext(
    apiKey: apiKey,
    username: username,
    password: password,
    paymentAmount: 42.00,
    merchantUniquePaymentId: mupid,
  ),
);

switch (result) {
  case ZpCallbackVerified():
    // authentic — read whatever fields you need from requestBody
  case ZpCallbackRejected():
  case ZpCallbackMalformed():
    // reject the webhook
}
```

## More

- Client SDK that presents the resulting checkout URL: [`zenpay_flutter`](../zenpay_flutter/README.md).
- A runnable example app plus reference backend, and the full interactive walkthrough (`zenpay-onboarding.html`): [the repository](https://github.com/ianmenethil/zp-flutter).
- Contributor source guide: [CLAUDE.md](CLAUDE.md).
