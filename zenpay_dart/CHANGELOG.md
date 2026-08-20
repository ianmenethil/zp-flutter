## 0.1.0

Initial port of the `@ianmenethil/zp-hcp@0.1.30` shared/server API surface:

- SHA3-512 fingerprint generation (`createZpFingerprint`) for the Authorise request.
- Hosted-checkout Authorise launch URL construction (`createZpCheckoutUrl`) with single-pass percent-encoding.
- Server-to-server callback authenticity verification (`verifyZpCallback`, `validateZpCallbackBody`) across payment, custom payment, preauthorization, and tokenisation modes.
- Stateless HMAC-SHA3-512 signed callback URL tokens (`createZpCallbackUrlToken`, `verifyZpCallbackUrlToken`) for correlating returns without server-side session state.
- Wire enums (`ZpPluginMode`, `ZpDisplayMode`, `ZpUserMode`, `ZpOverrideFeePayer`, `ZpPaymentStatus`) and shared crypto/ID primitives (`createSha3_512`, `createZpMupid`, `createZpTimestamp`, `zpAmountToCents`).
