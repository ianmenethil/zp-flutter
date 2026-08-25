# example/backend — Reference Merchant Backend

Reference merchant backend for the combined ZenPay example: a Shelf HTTP server that creates checkout sessions, verifies ZenPay webhooks, and brokers the browser return. It is a _reference implementation_, not a library — merchants copy the pattern, not the package.

---

## Source Guide

Overview of every source file, detailing each file's purpose along with a concise breakdown of its notable classes, functions, and constants — what they do, why they exist, and where they're used.

### `bin/server.dart`

**Overview:** Process entrypoint. Sets up colored structured logging, loads config, refuses to start when required env vars are missing, starts the periodic `AttemptStore` purge timer, and serves the Shelf handler until `SIGINT`.

- **`_levelColor(Level level)`**: maps a `logging` `Level` to an ANSI color code (red for severe/shout, yellow for warning, cyan for info, gray otherwise); used by the root logger's `onRecord` listener.
- **`main()`**: entrypoint — configures `Logger.root`, calls `loadConfig()`, refuses to start if `sessionConfigurationErrors`/`callbackConfigurationErrors` report missing env vars or `recaptchaConfigurationErrors` reports a partially-configured reCAPTCHA, starts a `Timer.periodic` purge of `AttemptStore` keyed by `checkoutStatusTtlMinutes`, serves `buildHandler` via `shelf_io.serve`, and awaits `ProcessSignal.sigint` to shut down cleanly.

### `lib/src/attempt_store.dart`

**Overview:** In-memory repository for `CheckoutAttempt` records, indexed by `merchantUniquePaymentId` and by idempotency key, with a TTL purge. A reference detail, not a durability guarantee — a real merchant backend persists attempts.

- **`class AttemptStoreError`**: thrown on an internal store invariant violation (`'DUPLICATE_CHECKOUT_ATTEMPT'`, `'CHECKOUT_ATTEMPT_NOT_FOUND'`); carries a machine-readable `code`.
- **`class AttemptStore`**: in-memory checkout-attempt store — `create` inserts a new attempt (throwing on duplicate MUPID), `getByMerchantPaymentId`/`getByIdempotencyKey` look up an attempt, `replace` updates an existing attempt's fields, and `purgeCreatedBefore` removes attempts older than a cutoff; used throughout `server_app.dart`'s route handlers and by `bin/server.dart`'s periodic purge timer.

### `lib/src/checkout_token.dart`

**Overview:** Signed checkout-exchange capability tokens — an example-backend concept, not part of `zenpay_dart`. Binds every immutable input needed to build one specific ZenPay attempt into a short-lived signed capability that `POST /checkout/exchange` verifies and replays deterministically. Deliberately separate from `zenpay_dart`'s `ZpCallbackUrlToken` (`t`) — see `token_keys.dart` for the key-level separation.

- **`class CheckoutTokenPayload`**: immutable claims of a checkout token (MUPID, mode, client, customer fields, timestamp, amount) — everything `/checkout/exchange` needs to deterministically rebuild the same ZenPay attempt on every exchange of the same token.
- **`sealed class CheckoutTokenResult`**: base result class for token verification (`CheckoutTokenVerified` or `CheckoutTokenFailure`); returned by `verifyCheckoutToken`.
- **`final class CheckoutTokenVerified`**: wraps a successfully verified and decoded `CheckoutTokenPayload`.
- **`enum CheckoutTokenFailureReason`**: why a checkout token failed verification (`malformed`, `badSignature`, `expired`, `wrongScope`).
- **`final class CheckoutTokenFailure`**: a failed checkout token verification carrying its `CheckoutTokenFailureReason`.
- **`createCheckoutToken(CheckoutTokenPayload payload, Object secret, {required int expiresInSeconds})`**: mints a signed, stateless checkout token; called by `session_service.dart`'s `prepareCheckout`.
- **`verifyCheckoutToken(String token, Object secret)`**: verifies and decodes a token minted by `createCheckoutToken`; called by `session_service.dart`'s `exchangeCheckout`.

### `lib/src/config.dart`

**Overview:** Runtime configuration for the example backend — loads settings from a `.env` file overlaid with process environment variables (process environment variables always take precedence).

- **`class ZenPayCredentials`**: ZenPay API credentials (`merchantCode`, `apiKey`, `username`, `password`) used for fingerprinting and callback verification; must never be logged or serialized to client responses.
- **`class ZenPayConfig`**: ZenPay Hosted Payment Page endpoint configuration and allowlist — `hppEndpointUrl`, `allowedCheckoutHosts`, `credentials`.
- **`class AppConfig`**: immutable runtime configuration for the whole backend — port, public base URL, CORS origin, TTLs, `tokenSecret` (the root secret every token type derives its signing key from — see `token_keys.dart`), rate limit, reCAPTCHA settings, and `zenPay`.
- **`loadConfig()`**: loads `AppConfig` from `.env` overlaid by real process environment variables; called once by `bin/server.dart`.
- **`sessionConfigurationErrors(AppConfig config)`**: lists environment variables missing for session creation (ZenPay credentials, `TOKEN_SECRET`); used by `bin/server.dart` to refuse startup and by `server_app.dart` to 503 checkout requests.
- **`callbackConfigurationErrors(AppConfig config)`**: lists environment variables missing for callback verification; same startup/503 usage as above.
- **`recaptchaConfigurationErrors(AppConfig config)`**: reCAPTCHA is optional but atomic — returns `[]` when `RECAPTCHA_PROJECT_NUMBER`/`RECAPTCHA_SERVICE_ACCOUNT_JSON`/`RECAPTCHA_SITE_KEY_WEB` are all empty (disabled) or all set (enabled), otherwise the names of whichever are still empty; used by `bin/server.dart` to refuse startup rather than silently render the client widget with server-side enforcement off.

### `lib/src/models.dart`

**Overview:** Checkout domain models and ZenPay status mapping.

- **`enum CheckoutClient`**: presentation environment the checkout session was initiated from (`web`, `mobile`) — iframe checkout is disabled project-wide; `tryParse` parses the `X-Client` header value.
- **`enum MerchantPaymentStatus`**: merchant-facing payment lifecycle state returned during status polling (`created` through `unknown`).
- **`mapZenPayStatus(int statusCode)`**: translates a raw ZenPay wire status code into a `MerchantPaymentStatus`; used by `server_app.dart`'s callback handler.
- **`class CheckoutAttempt`**: tracks the payment identifier, launch parameters, and verified callback results for one ZenPay checkout attempt — its identity is its `merchantUniquePaymentId`; `copyWith` returns a modified copy.
- **`class PrepareCheckoutBody`**: validated `POST /api/v1/checkout/token` request body.
- **`class ExchangeCheckoutResponse`**: launch data returned to the client from `POST /api/v1/checkout/exchange`; `toJson()` serializes it to the response body shape.
- **`class HttpError`**: controlled HTTP exception carrying a status code and machine-readable code; thrown by request handlers and turned into a `{"error": code}` JSON response by `server_app.dart`'s `buildHandler`.

### `lib/src/rate_limiter.dart`

**Overview:** Fixed-window request rate limiter. Ported from `development/samples/backend/lib/src/rate_limiter.dart` (`development/` has since been deleted from the repo; this is the surviving copy).

- **`class FixedWindowRateLimiter`**: a fixed-window request-rate limiter keyed by an arbitrary string (typically client IP) — `allow(key)` returns whether a request is permitted within the configured `limit`/`window`; used by `server_app.dart` to bound the anonymous checkout-creation and callback endpoints per IP.

### `lib/src/recaptcha_verifier.dart`

**Overview:** Verifies reCAPTCHA Enterprise tokens against Google Cloud, gating `POST /checkout/token` for web clients only — mobile requests skip this check entirely.

- **`class RecaptchaResult`**: outcome of a reCAPTCHA Enterprise assessment — `valid`.
- **`abstract interface class RecaptchaVerifier`**: verifies a client-supplied token for an expected action under a site key; implemented by `GoogleCloudRecaptchaVerifier` and faked in tests so they never hit Google's real endpoint.
- **`final class GoogleCloudRecaptchaVerifier`**: `RecaptchaVerifier` backed by the official `googleapis` reCAPTCHA Enterprise REST client — no third-party JWT library; the `.withApi` constructor bypasses service-account credential loading for tests. `verify` builds and sends an `Assessment` request, checks token validity, action match, and risk score, and redacts the client token before logging the request/response.

### `lib/src/security.dart`

**Overview:** Callback signature verification and timing-safe comparison — derives the merchant-facing fields this backend needs out of a ZenPay webhook once `zenpay_dart` has verified authenticity.

- **`constantTimeEqual(String a, String b)`**: compares two strings in constant time; used for reference/cookie/header comparisons outside the SDK's own hash checks.
- **`class CallbackFields`**: callback fields this backend derives from ZenPay's raw response — `reference`, `statusCode`, optional `failureCode`/`failureReason`, and the unfiltered `rawPayload`.
- **`class CallbackVerification`**: result of authenticating an incoming ZenPay webhook body — `.ok(fields)` for success, `.rejected(reason)` for failure (`'malformed'` or `'rejected'`).
- **`verifyCallback(Map<String, Object?> payload, CheckoutAttempt attempt, ZenPayCredentials credentials)`**: verifies an incoming webhook via `zenpay_dart`'s `verifyZpCallback` and derives `CallbackFields` from the payload on success; called by `server_app.dart`'s callback handler.

### `lib/src/server_app.dart`

**Overview:** The example backend's HTTP surface — health, two-step checkout creation, status lookup, callback verification, and browser return. A minimal demo backend, not a hardened one — see § 1 Scope & Responsibilities for what "minimal" means here and why.

- **`buildHandler(AppConfig config, AttemptStore store, {RecaptchaVerifier? recaptchaVerifier})`**: builds the top-level Shelf handler for every route below — parses/logs each request into one merged `http_trace` record, catches `HttpError` and unexpected exceptions into a JSON `{"error": code}` response, handles CORS preflight, and echoes `X-Request-Id`; called by `bin/server.dart`.
- **`describeRoutes()`**: returns the server's registered `(method, path)` route table, for `bin/server.dart`'s startup log.
- **`logEvent(String event, {Map<String, Object?> fields, bool isError})`**: logs a structured JSON event line; used by `bin/server.dart`'s `server_started` log.
- **`_handleCreateCheckoutToken`** (`POST /api/v1/checkout/token`): step 1 of checkout creation — rate-limits, validates the request body, runs the web-only reCAPTCHA check, and returns a signed checkout token via `session_service.dart`'s `prepareCheckout`.
- **`_handleExchangeCheckout`** (`POST /api/v1/checkout/exchange`): step 2 — verifies the `Authorization: Bearer` checkout token and builds (or replays) the ZenPay checkout URL via `session_service.dart`'s `exchangeCheckout`.
- **`_handleGetSession`** (`GET /api/v1/sessions`): returns the backend's authoritative status for the attempt named by the verified `?t=` token — no caller-supplied id is ever trusted directly.
- **`_handleCallback`** (`POST /api/v1/callbacks`): verifies the ZenPay `ValidationCode` signature via `security.dart`'s `verifyCallback` and applies the result to the matching stored attempt — the sole authoritative source of payment status.
- **`_handleReturn`** (`GET /return`): the browser landing page after ZenPay redirects back; marks the attempt as browser-returned (provisional, not callback-verified) and forwards to the app/web return destination.
- **`_handleWellKnown`**: serves the App Link / Universal Link verification files (`assetlinks.json`, `apple-app-site-association`) from `well_known/`.

### `lib/src/session_service.dart`

**Overview:** Two-step checkout: prepare a signed capability, then exchange it for a ZenPay checkout URL. No outbound network call happens at launch time — the launch URL is computed locally via `package:zenpay_dart`.

- **`returnPath`, `callbacksPath`, `appReturnPath`**: route path constants — where ZenPay redirects the browser, where it POSTs the server-to-server callback, and where the mobile App Link / Universal Link config points, respectively.
- **`appReturnUriFor(CheckoutAttempt attempt, AppConfig config)`**: resolves the return URI for an attempt's client kind — a path on this backend for mobile, `config.appReturnUriWeb` for web.
- **`prepareCheckout(PrepareCheckoutBody body, String idempotencyKey, AppConfig config, AttemptStore store)`**: step 1 — validates, resolves the trusted amount, mints a fresh MUPID/timestamp, persists a pending `CheckoutAttempt`, and returns a signed checkout token; a repeated `idempotencyKey` re-mints a token for the same attempt rather than creating a new one.
- **`exchangeCheckout(String checkoutToken, AppConfig config, AttemptStore store)`**: step 2 — verifies the checkout token and builds (or, on replay, reuses) the ZenPay checkout URL for the attempt it names, via `_buildCheckoutUrl`.
- **`_buildCheckoutUrl(...)`**: computes the SHA3-512 fingerprint via `zenpay_dart`'s `createZpFingerprint`, mints the signed return/status token (`t`) via `createZpCallbackUrlToken`, and builds the validated HCP launch URL via `createZpCheckoutUrl`; called by `exchangeCheckout`.
- **`class ZenPaySessionException`**: thrown when checkout session URL generation fails or violates security allowlists; carries a machine-readable `code`.
- **`resolveCheckoutUrl(String endpointUrl, AppConfig config)`**: validates that a generated launch URL uses HTTPS and targets an allowed host from `config.zenPay.allowedCheckoutHosts`.

### `lib/src/signed_token.dart`

**Overview:** Shared HMAC-SHA3-512 signed-token codec underlying `checkoutToken` (`checkout_token.dart`), plus `deriveTokenKey` — the domain-separation primitive `token_keys.dart` uses so `checkoutToken` and `zenpay_dart`'s own `ZpCallbackUrlToken` each sign with a cryptographically distinct derived key despite sharing one configured root secret.

- **`sealed class SignedTokenDecodeResult`**: base result class for `decodeSignedToken` (`SignedTokenDecoded`, `SignedTokenMalformed`, or `SignedTokenBadSignature`).
- **`final class SignedTokenDecoded`**: the token's signature verified and its body decoded to a `claims` map — callers still own validating its shape.
- **`final class SignedTokenMalformed`**: the token was too short, not valid base64url, or not a JSON object.
- **`final class SignedTokenBadSignature`**: the signature does not match the supplied secret.
- **`deriveTokenKey(Object rootSecret, String purpose)`**: derives a purpose-scoped signing key from `rootSecret` via HMAC-SHA3-512 over `purpose` — an HKDF-style domain separator; used by `token_keys.dart`.
- **`encodeSignedToken(Map<String, Object?> claims, Object secret)`**: encodes claims as a compact HMAC-SHA3-512 signed token; used by `checkout_token.dart`'s `createCheckoutToken`.
- **`decodeSignedToken(String token, Object secret)`**: decodes and verifies a token minted by `encodeSignedToken`; used by `checkout_token.dart`'s `verifyCheckoutToken`.

### `lib/src/token_keys.dart`

**Overview:** Purpose-scoped signing keys, all derived from the one configured root secret (`AppConfig.tokenSecret`) — real cryptographic domain separation between `checkoutToken` and `zenpay_dart`'s `ZpCallbackUrlToken`, not just a `scope` claim checked after decoding.

- **`checkoutTokenKey(AppConfig config)`**: signing key for `checkoutToken` (`checkout_token.dart`); derived via `deriveTokenKey` with the `'checkout-token-v1'` purpose label.
- **`callbackTokenKey(AppConfig config)`**: signing key for `zenpay_dart`'s `ZpCallbackUrlToken` (`t`), passed as the `Object secret` argument the SDK already accepts; derived with the `'callback-token-v1'` purpose label.

## Related Guides

- **[Combined Example](../CLAUDE.md)** — Two-app architecture, how this backend and `example/app` fit together.
- **[zenpay_dart](../../zenpay_dart/CLAUDE.md)** — The SDK this backend depends on (resolved to `../../zenpay_dart` by the root Dart pub workspace, not a `path:` dependency) for fingerprinting, callback verification, and callback tokens.
- **[example/app](../app/CLAUDE.md)** — The Flutter client this backend serves sessions to.

---

## 1. Scope & Responsibilities

- Holds the ZenPay API key, merchant credentials, and `TOKEN_SECRET` (the root secret every token type derives its signing key from). These never leave this process — see `.env.example` for the full variable list.
- Builds checkout launch URLs and fingerprints via `zenpay_dart`; never calls ZenPay outbound to do so (fingerprinting is local).
- Verifies incoming ZenPay webhooks (`POST /api/v1/callbacks`) via `zenpay_dart`'s constant-time `ValidationCode` check — this is the only source of truth for payment status. The browser return (`GET /return`) is provisional only.
- `lib/src/attempt_store.dart` is an in-memory store with a TTL purge (`CHECKOUT_STATUS_TTL_MINUTES`). It is a reference detail, not a durability guarantee — a real merchant backend persists attempts.
- This is a **minimal demo backend**, not a hardened one — deliberately: no merchant login, no static Bearer token (see the doc comment at the top of `lib/src/server_app.dart`). Checkout creation is a **two-step token/exchange model**, not a single anonymous "mint me a checkout URL" endpoint — see `lib/src/session_service.dart`'s doc comment and `README.md`'s Checkout Flow section. `POST /api/v1/checkout/token` prepares a signed, short-lived `checkoutToken` binding a fresh MUPID/timestamp and the backend-resolved amount; `POST /api/v1/checkout/exchange` verifies it and builds the ZenPay checkout URL — replaying the same token resolves to the same attempt, never a new one. Both are rate-limited per IP (`CHECKOUT_RATE_LIMIT_PER_MINUTE`, `lib/src/rate_limiter.dart`) — this is bounding an anonymous admission boundary, not authenticating it; see README's Security Model. Status lookup (`GET /api/v1/sessions`) and the browser return (`GET /return`) are gated on a required `?t=` query token — a `zenpay_dart` `ZpCallbackUrlToken` (HMAC-SHA3-512, signed with a key derived from `TOKEN_SECRET`) minted at exchange time. Nothing trusts a caller-supplied id directly; a token is the only thing authorizing a lookup. `POST /api/v1/callbacks` is verified separately, by `ValidationCode` alone (ZenPay calls it directly, so it carries no token).
- Idempotency on `POST /api/v1/checkout/token` is required (`Idempotency-Key` header, 16–128 chars) — do not remove or make optional. This is HTTP-level duplicate-request protection, a distinct concern from MUPID (ZenPay's own attempt-uniqueness id) — do not merge them.
- **No `merchantUniquePaymentId` special-casing.** It is an opaque field passed through to `zenpay_dart` and stored as a lookup key in `AttemptStore`, same as any other backend would key its own storage. Do not add validation, matching, or rejection logic specific to it. There is no separate `attemptId` — a `CheckoutAttempt`'s identity is its MUPID.
- **There is no `sessionId`, `sessionToken`, or retry concept anywhere in this backend** — removed deliberately (see git history if you need the old design). A failed/dismissed/timed-out checkout followed by another Pay tap is just a new, unrelated `POST /api/v1/checkout/token` call with a fresh MUPID; do not reintroduce grouping, retry policy, or a session-scoped token to correlate attempts. If a merchant genuinely needs cross-attempt correlation, that is the integrator's own storage layer, not this SDK/backend's job.
- `lib/src/recaptcha_verifier.dart` gates `POST /checkout/token` with a Google Cloud reCAPTCHA Enterprise assessment, verified via the official `googleapis` REST client — no third-party JWT library. Web checkout requests only: mobile requests (`X-Client: mobile`) skip this check entirely, since there's no reCAPTCHA client on Android/iOS. Optional: enforced only when `RECAPTCHA_SERVICE_ACCOUNT_JSON` is configured; empty disables it for local dev. Tests inject a fake `RecaptchaVerifier` rather than hitting Google's real endpoint.
- `checkoutToken` and the SDK's `t` token are two deliberately separate token types, both signed from one configured root secret (`TOKEN_SECRET`) but each with its own HMAC-SHA3-512 _derived_ signing key (`lib/src/token_keys.dart`, via `deriveTokenKey` in `lib/src/signed_token.dart`) — one purpose's token fails signature verification under another purpose's key, before any claim is even decoded. `checkoutToken` also carries an explicit `scope` claim checked on verify, as defense in depth on top of key separation, not instead of it — see `lib/src/checkout_token.dart`. Do not widen it to authorize what the `t` token is scoped to, and never mint or verify either token with the raw root secret directly — always go through `token_keys.dart`. Rotating `TOKEN_SECRET`, or changing a purpose label in `token_keys.dart`, invalidates every outstanding token of both types immediately — by design, since both are short-lived and nothing else depends on them surviving that.

## 2. Dart Strictness & Code Quality

Same rules as `zenpay_dart` — see [analysis_options.yaml](analysis_options.yaml): strict casts/inference/raw-types, no `dynamic`, comprehensive doc comments on exported members, `final` locals, standard `dart format`.

## 3. Verification Commands

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test:dart --scope=zenpay_example_backend
```

Or directly against this package:

```pwsh
Push-Location example/backend
dart analyze --fatal-infos
dart test
Pop-Location
```

To run the server itself, use `dart run cli.dart --server` from the repo root rather than `dart run bin/server.dart` directly — it handles `.env` prompting, health polling, and propagates `PUBLIC_BASE_URL` to `example/app` and the native Android/iOS App Link config.
