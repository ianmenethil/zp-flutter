# example/backend

Minimal reference merchant backend for the combined ZenPay example: a Shelf
HTTP server that creates checkout sessions, verifies ZenPay webhooks, and
brokers the browser return. Depends on [`zenpay_dart`](../../zenpay_dart/README.md),
resolved to the local package by the root Dart pub workspace (not a `path:`
dependency — see [`pubspec.yaml`](pubspec.yaml)).

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) (`AGENTS.md` here is a
symlink to it). Combined example overview: [../README.md](../README.md).

This is a **minimal demo backend**, deliberately — no merchant login, no
static Bearer token (see the doc comment atop `lib/src/server_app.dart`).
Checkout creation is anonymous but bounded: per-IP rate limiting and
short-lived signed capabilities stand in for authentication — see
[Security Model](#security-model).

---

## Quick Start

```bash
dart pub get      # via `melos bs` from the repo root — never run this directly
cp .env.example .env
```

Edit `.env` with your merchant credentials — see the table below.

Run it from the **repository root** (recommended — prompts for/updates
`PUBLIC_BASE_URL` and propagates it to `example/app`'s `.env` and the native
Android/iOS App Link config):

```pwsh
dart run cli.dart --server
```

Or directly, skipping that prompt/propagation:

```bash
dart run bin/server.dart
```

Listens on `0.0.0.0:<PORT>`, shuts down cleanly on `Ctrl+C`.

### Configuration

| Variable                         | Required | Description                                                                                                                                                                                                                                                                                                               |
| :------------------------------- | :------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `PORT`                           |          | HTTP listen port (default `7000`).                                                                                                                                                                                                                                                                                        |
| `PUBLIC_BASE_URL`                |    ✓     | Public HTTPS URL of this server. ZenPay derives `redirectUrl` and `callbackUrl` from it. Use a tunnel for local development: `cloudflared tunnel --url http://localhost:7000`.                                                                                                                                            |
| `ZENPAY_HPP_ENDPOINT_URL`        |    ✓     | Full HCP Authorise endpoint URL (e.g. `https://pay.sandbox.travelpay.com.au/Online/v5`).                                                                                                                                                                                                                                  |
| `ZENPAY_MERCHANT_CODE`           |    ✓     | Merchant code for the ZenPay account.                                                                                                                                                                                                                                                                                     |
| `ZENPAY_API_KEY`                 |    ✓     | API key for the ZenPay merchant account.                                                                                                                                                                                                                                                                                  |
| `ZENPAY_USERNAME`                |    ✓     | Hashed into the SHA3-512 fingerprint; never leaves this backend.                                                                                                                                                                                                                                                          |
| `ZENPAY_PASSWORD`                |    ✓     | Hashed into the SHA3-512 fingerprint; never leaves this backend.                                                                                                                                                                                                                                                          |
| `TOKEN_SECRET`                   |    ✓     | Root secret every token type (`checkoutToken`, the `?t=` return/status token) derives its own signing key from — see [Checkout Identity Model](#checkout-identity-model). Must be ≥32 bytes or session creation fails. `openssl rand -hex 32`. Rotating it invalidates every outstanding token of both types immediately. |
| `ALLOWED_APP_ORIGIN`             |          | Browser origin for CORS (default `http://localhost:3000`).                                                                                                                                                                                                                                                                |
| `APP_RETURN_URI_WEB`             |          | HTTPS URI the return broker redirects web clients to (default `https://localhost:3000/`).                                                                                                                                                                                                                                 |
| `ZENPAY_ALLOWED_CHECKOUT_HOSTS`  |          | Comma-separated allowlist of checkout URL hosts (default `pay.sandbox.travelpay.com.au`).                                                                                                                                                                                                                                 |
| `CHECKOUT_STATUS_TTL_MINUTES`    |          | How long to keep in-memory attempts before purging (default `60`).                                                                                                                                                                                                                                                        |
| `CHECKOUT_TOKEN_TTL_SECONDS`     |          | Lifetime of a `POST /api/v1/checkout/token` capability (default `300`) — short, since it only needs to survive the gap before `/checkout/exchange`.                                                                                                                                                                       |
| `CHECKOUT_RATE_LIMIT_PER_MINUTE` |          | Per-IP requests/minute on `/checkout/token` and `/checkout/exchange` (default `20`).                                                                                                                                                                                                                                      |
| `RECAPTCHA_PROJECT_NUMBER`       |          | GCP project _number_ (not ID) reCAPTCHA Enterprise assessments are created under. When set, requires a valid `X-Recaptcha-Token` on web checkout-creation requests. Empty disables enforcement.                                                                                                                          |
| `RECAPTCHA_SERVICE_ACCOUNT_JSON` |          | GCP Service Account JSON (raw or file path) authorized to call the reCAPTCHA Enterprise API, used to verify reCAPTCHA tokens. Required when `RECAPTCHA_PROJECT_NUMBER` is set.                                                                                                                                           |
| `RECAPTCHA_SITE_KEY_WEB`         |          | reCAPTCHA site key the web client's assessment token must match. Required when `RECAPTCHA_PROJECT_NUMBER` is set.                                                                                                                                                                                                        |

---

## API Endpoints

| Method | Path                                      |           Auth           | Description                                                                                                                                                                                                                                                                               |
| :----- | :---------------------------------------- | :----------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST` | `/api/v1/checkout/token`                  |                          | Step 1 — prepares a checkout, resolves the trusted amount, returns a signed `checkoutToken`. Requires `X-Client` (`web`/`mobile`) and `Idempotency-Key` (16–128 chars) headers. Anonymous but rate-limited per IP and reCAPTCHA-gated for web clients. `X-Request-Id` is echoed back for log correlation. |
| `POST` | `/api/v1/checkout/exchange`               | `Bearer <checkoutToken>` | Step 2 — verifies the token, builds (or, on replay, reuses) the ZenPay checkout URL.                                                                                                                                                                                                       |
| `GET`  | `/api/v1/sessions?t=...`                  |        `t` token         | Authoritative status for the one ZenPay attempt named by the verified callback URL token.                                                                                                                                                                                                 |
| `POST` | `/api/v1/callbacks`                       |                          | ZenPay server-to-server webhook. Verified by `ValidationCode` alone, no `t` token.                                                                                                                                                                                                        |
| `GET`  | `/return?t=...`                           |        `t` token         | Browser redirect broker — 303 for mobile/web.                                                                                                                                                                                                                                             |
| `GET`  | `/.well-known/assetlinks.json`            |                          | Android App Links verification file.                                                                                                                                                                                                                                                      |
| `GET`  | `/.well-known/apple-app-site-association` |                          | iOS Universal Links verification file.                                                                                                                                                                                                                                                    |

There is no `POST` endpoint that mints a fresh ZenPay checkout URL from a
single anonymous request — see [Security Model](#security-model) for why.

---

## Checkout Identity Model

Two identifiers. Neither is authentication.

```
requestId
  = HTTP/log tracing only — one per incoming request, never persisted
    as identity, never inside a token

MUPID
  = unique identity of one ZenPay checkout attempt
  = generated fresh every time `/checkout/token` prepares an attempt
  = stored in checkoutToken
  = used for fingerprint/callback/status correlation
```

There is no server-side concept of a "retry" or a logical session grouping
multiple attempts. If checkout fails, is dismissed, or times out and the
customer presses Pay again, that is simply a **new ZenPay checkout attempt
with a new MUPID**, created through the normal `/checkout/token` →
`/checkout/exchange` flow.

Two token types, both signed from one configured root secret
(`TOKEN_SECRET`) but kept deliberately separate two ways:

| Token                                          | Scope claim              | Authorizes                                                             |
| :--------------------------------------------- | :----------------------- | :--------------------------------------------------------------------- |
| `checkoutToken`                                | `checkout:exchange`      | `POST /checkout/exchange` for one attempt (one MUPID) only             |
| `t` (`ZpCallbackUrlToken`, from `zenpay_dart`) | — (unmodified SDK shape) | `GET /api/v1/sessions`, `GET /return` for one attempt (one MUPID) only |

1. **Key separation (primary).** `lib/src/token_keys.dart` derives a
   different signing key per token type from the one root secret
   (`deriveTokenKey` in `lib/src/signed_token.dart`: HMAC-SHA3-512 over a
   fixed purpose label). A token minted for one purpose fails _signature_
   verification under another purpose's key — this holds before any claim
   is even decoded, and covers the SDK's own `t` token too even though its
   `ZpCallbackUrlTokenPayload` shape is untouched.
2. **`scope` claim (defense in depth).** `checkoutToken` carries an explicit
   `scope` checked on verify — see `lib/src/checkout_token.dart`. This is a
   second layer, not the primary guarantee: key separation alone already
   stops cross-verification.

**Rotating `TOKEN_SECRET`, or changing a purpose label in `token_keys.dart`,
invalidates every outstanding `checkoutToken` and `t` token immediately** —
there's no key versioning or grace period. This is acceptable by design:
both are short-lived (minutes to an hour) and this backend keeps no other
state that depends on a token surviving past its own expiry.

The authoritative source of payment status is always the signed ZenPay
callback, never a browser return or a token's mere existence.

---

## Checkout Flow

```
┌─────────────┐                    ┌────────────────┐          ┌──────────┐
│  Client App  │                    │  This Backend   │          │  ZenPay  │
└──────┬──────┘                    └───────┬────────┘          └─────┬────┘
       │  POST /checkout/token             │                        │
       │  {mode, paymentAmount, customer..}│                        │
       │───────────────────────────────────▶│                        │
       │        {checkoutToken}             │  (resolves trusted     │
       │◀────────────────────────────────────┤   amount; mints       │
       │                                    │   mupid+ts; persists   │
       │  POST /checkout/exchange           │   a pending attempt)   │
       │  Authorization: Bearer <token>     │                        │
       │───────────────────────────────────▶│                        │
       │  {checkoutUrl}                     │  (builds fingerprint   │
       │◀────────────────────────────────────┤   + checkout URL,     │
       │                                    │   stores it)           │
       │  Open checkoutUrl                                          │
       │──────────────────────────────────────────────────────────▶│
       │                                    │   POST /api/v1/callbacks
       │                                    │◀───────────────────────┤
       │                                    │   (SHA3-512 verified)   │
       │  GET /return                       │                        │
       │───────────────────────────────────▶│                        │
       │  303 → app return                  │                        │
       │◀────────────────────────────────────┤                        │
       │  GET /api/v1/sessions?t=...        │                        │
       │───────────────────────────────────▶│                        │
       │  {status: successful}              │                        │
       │◀────────────────────────────────────┤                        │
```

If checkout fails, is dismissed, or times out, pressing Pay again is simply
a fresh `POST /checkout/token` → `/checkout/exchange` — a new, unrelated
MUPID and checkout URL. There is no app- or backend-level "retry" concept.

Replaying the _same_ `checkoutToken` against `/checkout/exchange` twice
always resolves to the same attempt (same MUPID, same checkout URL) — it is
not a way to mint unlimited attempts from one token.

---

## Security Model

- **SHA3-512 fingerprint & callback validation** — as in `zenpay_dart`'s own
  [Security Model](../../zenpay_dart/README.md#security-model); unchanged here.
- **Client-supplied amount** — `POST /checkout/token` requires a positive
  `paymentAmount` for Make Payment (mode 0), Custom Payment (mode 2), and
  Pre-Auth (mode 3); ZenPay's own fingerprint rule hashes `"0"` for Custom
  Payment regardless of what's sent.
- **Checkout-token replay, not reuse** — `merchantUniquePaymentId` and the
  ZenPay timestamp are minted once, at `/checkout/token` time, and carried
  inside the signed `checkoutToken`. `/checkout/exchange` never mints a new
  one; replaying the same token resolves to the same attempt.
- **This is still an anonymous admission boundary** — there is no merchant
  login in this demo, so `POST /checkout/token` cannot be made airtight by
  the token/exchange split alone. It is bounded instead by a per-IP rate
  limit (`CHECKOUT_RATE_LIMIT_PER_MINUTE`), an `Idempotency-Key` requirement,
  strict input validation, and a 64KB body cap. reCAPTCHA Enterprise
  verification is available at this exact boundary for web checkout requests
  (`lib/src/recaptcha_verifier.dart`) — set `RECAPTCHA_PROJECT_NUMBER`,
  `RECAPTCHA_SERVICE_ACCOUNT_JSON`, and `RECAPTCHA_SITE_KEY_WEB` to require a
  valid `X-Recaptcha-Token` on `POST /checkout/token`; see
  `lib/src/server_app.dart`'s doc comment. Mobile checkout requests
  (`X-Client: mobile`) skip this check entirely — there is no reCAPTCHA client
  on Android/iOS. None of the above is authentication; don't confuse rate
  limiting, idempotency, or a signed capability token with it.
- **Token hygiene** — full tokens are never logged; structured logs carry
  `requestId`/`merchantUniquePaymentId`/`paymentReference` instead.
  Signature checks are constant-time (`package:hashlib`'s
  `HashDigest.isEqual`). See [Checkout Identity Model](#checkout-identity-model)
  for the per-purpose key derivation backing this.
- **No sensitive data in logs** — passwords, card numbers, CVVs, secrets,
  and raw tokens are never logged.

---

## Related Guides

- **[CLAUDE.md](CLAUDE.md)** — Scope and responsibilities.
- **[../../zenpay_dart/README.md](../../zenpay_dart/README.md)** — The SDK this backend is built on.
- **[../app/README.md](../app/README.md)** — The Flutter client this backend serves.
