# zenpay_dart — Pure Dart Backend SDK

Server-side logic and cryptography for ZenPay Hosted Checkout: fingerprints, launch URLs,
callback verification, signed callback URL tokens. Server-side only — never import this
from a Flutter mobile app or frontend package; it handles credentials and signing.

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[zenpay_flutter](../zenpay_flutter/CLAUDE.md)** — The client SDK that presents the checkout URL this package builds.
- **[PCI_SAQ_A.md](../PCI_SAQ_A.md)** — PCI posture for the flow this package secures.
- **[README.md](README.md)** — Usage.

## Source Guide

- **[build_checkout_url.dart](lib/src/build_checkout_url.dart)** — `createZpCheckoutUrl`: validates a `ZpCheckoutOptions` request and assembles the percent-encoded hosted-checkout launch URL.
- **[build_fingerprint.dart](lib/src/build_fingerprint.dart)** — `createZpFingerprint`: computes the SHA3-512 launch fingerprint from merchant credentials and order fields.
- **[checkout_defaults.dart](lib/src/checkout_defaults.dart)** — Default option/UI-hint values applied when a caller omits them. Internal, not exported.
- **[constants.dart](lib/src/constants.dart)** — Shared constants, validation regexes, and error message text. Internal, not exported.
- **[crypto_utils.dart](lib/src/crypto_utils.dart)** — SHA3-512 hashing, constant-time comparison, dollar-to-cents conversion, MUPID/timestamp generation.
- **[sign_callback_token.dart](lib/src/sign_callback_token.dart)** — `createZpCallbackUrlToken`/`verifyZpCallbackUrlToken`: HMAC-SHA3-512 signed tokens for callback-URL metadata.
- **[verify_callback.dart](lib/src/verify_callback.dart)** — `verifyZpCallback`: authenticates an incoming ZenPay webhook via constant-time `ValidationCode` comparison — the sole source of truth for payment status.
- **[models/callback_input.dart](lib/src/models/callback_input.dart)** — `ZpVerifyCallbackContext` and the `ZpCallbackResult` sealed hierarchy.
- **[models/callback_token_data.dart](lib/src/models/callback_token_data.dart)** — Callback-URL token payload, options, and the `ZpCallbackUrlTokenResult` sealed hierarchy.
- **[models/checkout_options.dart](lib/src/models/checkout_options.dart)** — `ZpCheckoutOptions`, the hosted-checkout request model.
- **[models/enums.dart](lib/src/models/enums.dart)** — Wire enums: `ZpPluginMode`, `ZpDisplayMode`, `ZpUserMode`, `ZpOverrideFeePayer`, `ZpPaymentStatus`.
- **[models/fingerprint_result.dart](lib/src/models/fingerprint_result.dart)** — `ZpFingerprintInput` and the `ZpFingerprintResult` sealed hierarchy.
- **[zenpay_dart.dart](lib/zenpay_dart.dart)** — Barrel export for the public API; `checkout_defaults.dart`/`constants.dart` stay internal.

## Verification

Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test:dart --scope=zenpay_dart
```
