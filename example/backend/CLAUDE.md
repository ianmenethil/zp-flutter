# example/backend — Reference Merchant Backend

Reference merchant backend for the combined ZenPay example: a Shelf HTTP server that creates checkout sessions, verifies ZenPay webhooks, and brokers the browser return. It is a _reference implementation_, not a library — merchants copy the pattern, not the package.

---

## File list and purpose

- **[lib/src/attempt_store.dart](lib/src/attempt_store.dart)** — in-memory checkout-attempt store with a TTL purge.
- **[lib/src/checkout_token.dart](lib/src/checkout_token.dart)** — mints/verifies the signed `checkoutToken` capability used by the two-step checkout flow.
- **[lib/src/config.dart](lib/src/config.dart)** — loads `AppConfig` from environment/`.env`.
- **[lib/src/models.dart](lib/src/models.dart)** — checkout domain models and ZenPay status mapping.
- **[lib/src/rate_limiter.dart](lib/src/rate_limiter.dart)** — per-IP fixed-window rate limiter for the anonymous checkout-creation boundary.
- **[lib/src/recaptcha_verifier.dart](lib/src/recaptcha_verifier.dart)** — Google Cloud reCAPTCHA Enterprise assessment check; see Security below.
- **[lib/src/security.dart](lib/src/security.dart)** — constant-time comparison and ZenPay callback verification helpers.
- **[lib/src/server_app.dart](lib/src/server_app.dart)** — the HTTP surface: routes, request parsing, response building.
- **[lib/src/session_service.dart](lib/src/session_service.dart)** — the two-step checkout token/exchange flow.
- **[lib/src/signed_token.dart](lib/src/signed_token.dart)** / **[lib/src/token_keys.dart](lib/src/token_keys.dart)** — per-purpose HMAC-SHA3-512 key derivation shared by `checkoutToken` and the SDK's `t` token.

## Related Guides

- **[Combined Example](../CLAUDE.md)** — Two-app architecture, how this backend and `example/app` fit together.
- **[zenpay_dart](../../zenpay_dart/CLAUDE.md)** — The SDK this backend depends on (`../../zenpay_dart` via Melos `path:`) for fingerprinting, callback verification, and callback tokens.
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
- `lib/src/recaptcha_verifier.dart` gates `POST /checkout/token` with a Google Cloud reCAPTCHA Enterprise assessment, verified via the official `googleapis` REST client — no third-party JWT library. Web checkout requests only: mobile requests (`X-Client: mobile`) skip this check entirely, since there's no reCAPTCHA client on Android/iOS. Optional: enforced only when `FIREBASE_PROJECT_NUMBER` and `RECAPTCHA_SITE_KEY_WEB` are configured; empty disables it for local dev. Tests inject a fake `RecaptchaVerifier` rather than hitting Google's real endpoint.
- `checkoutToken` and the SDK's `t` token are two deliberately separate token types, both signed from one configured root secret (`TOKEN_SECRET`) but each with its own HMAC-SHA3-512 _derived_ signing key (`lib/src/token_keys.dart`, via `deriveTokenKey` in `lib/src/signed_token.dart`) — one purpose's token fails signature verification under another purpose's key, before any claim is even decoded. `checkoutToken` also carries an explicit `scope` claim checked on verify, as defense in depth on top of key separation, not instead of it — see `lib/src/checkout_token.dart`. Do not widen it to authorize what the `t` token is scoped to, and never mint or verify either token with the raw root secret directly — always go through `token_keys.dart`. Rotating `TOKEN_SECRET`, or changing a purpose label in `token_keys.dart`, invalidates every outstanding token of both types immediately — by design, since both are short-lived and nothing else depends on them surviving that.

## 2. Dart Strictness & Code Quality

Same rules as `zenpay_dart` — see [analysis_options.yaml](analysis_options.yaml): strict casts/inference/raw-types, no `dynamic`, comprehensive doc comments on exported members, `final` locals, standard `dart format`.

## 3. Verification Commands

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```

Or directly against this package:

```pwsh
Push-Location example/backend
dart analyze --fatal-infos
dart test
Pop-Location
```

To run the server itself, use `dart run cli.dart --server` from the repo root rather than `dart run bin/server.dart` directly — it handles `.env` prompting, health polling, and propagates `PUBLIC_BASE_URL` to `example/app` and the native Android/iOS App Link config.
