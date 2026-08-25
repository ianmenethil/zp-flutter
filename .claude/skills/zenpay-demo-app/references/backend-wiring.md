# Backend wiring (`zenpay_dart`)

Only needed in `full` mode. The reference is `example/backend/lib/src/session_service.dart`
(URL building) and `example/backend/lib/src/security.dart` (callback verification) — both
are worth reading in full; they are short and they are the real thing.

Four `zenpay_dart` calls carry the entire integration. Everything else in `example/backend`
— rate limiter, reCAPTCHA, attempt store, derived token keys, idempotency — is reference
*hardening*. Real, deliberate, and worth copying into production; not required to demonstrate
the SDK. Skip what the demo does not need and say you skipped it.

---

## Call 1 — mint the identifiers (prepare)

```dart
final mupid = createZpMupid().value;        // 22-char base64url, unique per attempt
final timestamp = createZpTimestamp().value; // 'YYYY-MM-DDTHH:MM:SS' UTC
```

Mint both **once, at prepare time**, and carry them forward. Exchanging the same capability
twice must rebuild the same attempt, not a new one — that is what makes step 2 replay-safe.

## Call 2 — the fingerprint (exchange)

```dart
final fingerprint = switch (createZpFingerprint(ZpFingerprintInput(
  apiKey: credentials.apiKey,
  username: credentials.username,
  password: credentials.password,
  mode: pluginMode,
  paymentAmount: amount,
  merchantUniquePaymentId: ZpMupid(mupid),
  timestamp: ZpTimestamp(timestamp),
))) {
  ZpFingerprintSuccess(:final fingerprint) => fingerprint,
  ZpFingerprintFailure() => throw ZenPaySessionException('ZENPAY_FINGERPRINT_FAILED'),
};
```

SHA3-512 over a pipe-delimited string, computed locally. No network call happens here — the
launch URL is built entirely offline.

Pass `amount` through as-is. The SDK's own `resolveZpHashAmountField` already handles the
per-mode rules (Custom Payment always hashes `"0"`; Tokenise hashes `"0"` only when the
amount is null). Pre-resolving it yourself produces a fingerprint ZenPay rejects.

## Call 3 — the return/status token

```dart
final returnToken = createZpCallbackUrlToken(
  ZpCallbackUrlTokenPayload(
    mode: pluginMode,
    merchantUniquePaymentId: ZpMupid(mupid),
    timestamp: ZpTimestamp(timestamp),
    paymentAmount: amount,
  ),
  callbackTokenKey(config),                       // a DERIVED key, never the root secret
  ZpCallbackUrlTokenOptions(expiresInSeconds: ttl),
);
```

This is what makes `GET /api/v1/sessions?t=…` safe without any session concept: the MUPID
travels as a signed claim, so a lookup authorises itself. Nothing trusts a caller-supplied id.

## Call 4 — build the URL

```dart
final url = switch (createZpCheckoutUrl(ZpCheckoutOptions(
  url: config.zenPay.hppEndpointUrl.toString(),
  apiKey: credentials.apiKey,
  fingerprint: fingerprint,
  merchantCode: credentials.merchantCode,
  mode: pluginMode,
  timestamp: ZpTimestamp(timestamp),
  merchantUniquePaymentId: ZpMupid(mupid),
  customerEmail: customerEmail,
  redirectUrl: '<PUBLIC_BASE_URL>/return?t=$returnToken',
  callbackUrl: '<PUBLIC_BASE_URL>/api/v1/callbacks',
  redirectOnError: true,
  paymentAmount: amount,
  // ...customerName, customerReference, contactNumber, wallet flags
))) {
  ZpUrlSuccess(:final url) => url,
  ZpUrlFailure() => throw ZenPaySessionException('ZENPAY_CHECKOUT_URL_FAILED'),
};
```

Then validate what you built before handing it to a client — https, and a host on your own
allowlist. The reference does this in `resolveCheckoutUrl`; it is four lines and it is the
last place you can catch a misconfigured `ZENPAY_HPP_ENDPOINT_URL`.

**Log the launch URL in full.** Every value in it — `__ApiKey`, `__Fingerprint`,
`merchantCode`, the MUPID — is public: the customer's own browser receives the same URL.
Masking them adds no security and makes logs impossible to correlate. See
`zenpay_dart/CLAUDE.md` § 1.2 for the public-vs-secret table. The genuine secrets, which
never appear in any URL this SDK builds, are the **merchant password** and the **HMAC
secret**.

---

## Call 5 — verify the callback (the only one that decides payment)

```dart
final result = verifyZpCallback(mode, payload, ZpVerifyCallbackContext(
  apiKey: credentials.apiKey,
  username: credentials.username,
  password: credentials.password,
  paymentAmount: attempt.amount ?? 0,
  merchantUniquePaymentId: ZpMupid(attempt.merchantUniquePaymentId),
));

switch (result) {
  case ZpCallbackMalformed(): // 400 — structural problem
  case ZpCallbackRejected():  // 401 — ValidationCode failed
  case ZpCallbackVerified():  // authentic. NOW read the payload.
}
```

`ZpCallbackVerified` carries **no data** — it is pass/fail only. You already hold the body you
passed in; read the fields you need off it once authenticity is proven. Use
`mode.callbackReferenceField` to find the right reference field for the mode
(`paymentReference` / `preauthReference` / `token`).

It never throws on malformed input — callback bodies are attacker-reachable wire data, so
failures come back as values.

A demo that stores the verified result and serves it from `GET /api/v1/sessions` has
implemented the whole trust model. That is the point of the exercise.

**ZenPay does not retry a callback** (per the ZenPay product owner — the code in this repo
does not state this). So the lifecycle around `verifyZpCallback` matters as much as the call
itself: which HTTP status you return, how you find the attempt, and what you do with a
duplicate. `integration-contract.md` § Handling the callback has the full table — read it
before writing this route, not after.

---

## `.env`

Copy `example/backend/.env.example`; the scaffold seeds real values from
`example/backend/.env` when it exists. The ones without a working default:

| Variable | Notes |
|---|---|
| `ZENPAY_MERCHANT_CODE`, `ZENPAY_API_KEY`, `ZENPAY_USERNAME`, `ZENPAY_PASSWORD` | sandbox merchant credentials; not in this repo |
| `TOKEN_SECRET` | ≥ 32 bytes, separate from the ZenPay password — `openssl rand -hex 32` |
| `PUBLIC_BASE_URL` | `localhost` works until you need a real callback; ZenPay's webhook is server-to-server and cannot reach your machine |

The server should refuse to start session creation without these and return
`503 SESSION_CONFIGURATION_REQUIRED` rather than failing deeper in — copy that behaviour, it is the
difference between a five-second diagnosis and an hour.

reCAPTCHA is optional: leave `RECAPTCHA_PROJECT_NUMBER`, `RECAPTCHA_SERVICE_ACCOUNT_JSON`,
and `RECAPTCHA_SITE_KEY_WEB` empty to disable it for local dev. All three are required
together once any is set, it gates web clients only, and mobile always skips it. A demo
backend does not need it.

---

## What the demo backend can skip

| `example/backend` has | Skip in a demo because |
|---|---|
| `FixedWindowRateLimiter` | bounds an anonymous admission boundary in production; nothing in a local demo |
| `GoogleCloudRecaptchaVerifier` | web bot-gating; needs a GCP service account |
| `deriveTokenKey` / `token_keys.dart` | domain separation between two token types — keep it if you mint both, and never sign with the raw root secret |
| `AttemptStore` TTL purge | an in-memory map is fine for a demo; a real backend persists attempts |
| `Idempotency-Key` enforcement | genuinely useful, cheap to keep — keep it if the demo has a Pay button a user can double-tap |
