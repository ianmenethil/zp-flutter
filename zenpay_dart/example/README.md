# zenpay_dart example

Server-side ZenPay Hosted Checkout flow end to end. Run it:

```bash
dart run example/main.dart
```

[`main.dart`](main.dart) walks the three steps a merchant backend performs:

1. **Fingerprint** — `createZpFingerprint` computes the SHA3-512 digest over the seven
   pipe-delimited hash fields. One timestamp and one MUPID per attempt; reuse the same values
   for the URL you build from the digest.
2. **Authorise URL** — `createZpCheckoutUrl` assembles the launch URL locally, with no outbound
   network call, and percent-encodes every query value exactly once.
3. **Callback verification** — `verifyZpCallback` recomputes the expected `validationCode` and
   compares it in constant time. This is the *only* trustworthy confirmation that a payment
   completed: a browser redirect or a dismissed checkout is provisional.

Every entry point returns a sealed result you `switch` on — `verifyZpCallback` never throws, so
malformed and hostile callback bodies come back as `ZpCallbackMalformed` (respond 400) or
`ZpCallbackRejected` (respond 401) rather than as exceptions.

The example prints a **rejected** callback on purpose. Its body carries a well-formed but
deliberately wrong 128-hex `validationCode`, so the rejection path is demonstrated without
shipping a hardcoded valid digest.

Credentials are read from the environment (`ZP_API_KEY`, `ZP_USERNAME`, `ZP_PASSWORD`,
`ZP_MERCHANT_CODE`, `ZP_ENDPOINT`), never hardcoded; the in-file fallbacks are inert
stand-ins. The **merchant password** is the only genuine secret of the three — it is a hash
input and never appears in the launch URL.

The example prints the launch URL in full, which is correct: `__ApiKey`, `__Fingerprint` and
`merchantCode` are public values that the customer's own browser receives when it loads that
same URL. Do not mask them. See the public-vs-secret table in
[CLAUDE.md](../CLAUDE.md) for the full list.
