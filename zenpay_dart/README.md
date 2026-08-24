# zenpay_dart

Pure-Dart backend SDK for the ZenPay Hosted Checkout Plugin (HCP). Provides SHA3-512 fingerprint generation, launch URL construction, server-to-server callback verification, and signed callback URL tokens — everything a merchant backend needs to integrate with ZenPay's hosted payment page without any browser-side dependencies.

> **Server-side only.** Never import this package from a Flutter mobile app or frontend. Fingerprint generation and callback verification involve merchant credentials that must stay on your server.

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md). Monorepo overview: [../README.md](../README.md).

---

## Packages

| Package               | Path       | Description                                                                                                                                    |
| :-------------------- | :--------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| `zenpay_dart`         | `lib/`     | Core SDK: cryptographic fingerprinting, checkout URL builder, callback verifier, callback URL token signer, wire enums.                        |
| example backend       | `../example/backend/` | Reference merchant backend: Shelf HTTP server demonstrating session creation, status polling, callback handling, and browser-return brokering. See its [README](../example/backend/README.md). |
| example app           | `../example/app/`     | Reference Flutter client that requests sessions from the backend and presents checkout via `zenpay_flutter`. See its [README](../example/app/README.md). |

This package is one member of the [`zp-flutter-sdk`](../README.md) monorepo — the reference backend and app do not live inside `zenpay_dart` itself.

---

## Architecture

```
lib/
├── zenpay_dart.dart           # Barrel export (public API)
└── src/
    ├── callback.dart          # SHA3-512 callback verification
    ├── callback_token.dart    # HMAC-SHA3-512 signed URL tokens
    ├── checkout_url.dart      # Authorise launch URL construction
    ├── constants.dart         # Shared constants, regex patterns, error messages
    ├── crypto.dart            # SHA3-512, constant-time comparison, ID generation
    ├── defaults.dart          # Default ZpCheckoutOptions values
    ├── fingerprint.dart       # Outgoing fingerprint (SHA3-512 hash pipe)
    └── models/                # Request/result data classes and wire enums
        ├── callback_models.dart
        ├── callback_token_models.dart
        ├── checkout_options.dart
        ├── enums.dart
        └── fingerprint_models.dart
```

The reference backend lives at `../example/backend/` (own `lib/src/`,
`bin/server.dart`, `.env.example`) — see its
[README](../example/backend/README.md) for that layout.

For detailed per-entity documentation of every class, function, and enum:

- **[CLAUDE.md](CLAUDE.md)** — Core `zenpay_dart` package source guide (`AGENTS.md` here is a symlink to it).
- **[../example/backend/CLAUDE.md](../example/backend/CLAUDE.md)** — Reference backend guide.

---

## Quick Start

### Prerequisites

- Dart SDK ≥ 3.13.0
- A ZenPay sandbox or production merchant account

### 1. Install Dependencies

```bash
dart pub get
cd ../example/backend && dart pub get && cd -
```

### 2. Configure the Reference Backend

```bash
cp ../example/backend/.env.example ../example/backend/.env
```

Edit `../example/backend/.env` with your merchant credentials:

| Variable                        | Required | Description                                                                                                                                                                    |
| :------------------------------ | :------: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PORT`                          |          | HTTP listen port (default `7000`).                                                                                                                                             |
| `PUBLIC_BASE_URL`               |    ✓     | Public HTTPS URL of this server. ZenPay derives `redirectUrl` and `callbackUrl` from it. Use a tunnel for local development: `cloudflared tunnel --url http://localhost:7000`. |
| `ZENPAY_HPP_ENDPOINT_URL`       |    ✓     | Full HCP Authorise endpoint URL (e.g. `https://pay.sandbox.travelpay.com.au/Online/v5`).                                                                                       |
| `ZENPAY_MERCHANT_CODE`          |    ✓     | Merchant code for the ZenPay account.                                                                                                                                          |
| `ZENPAY_API_KEY`                |    ✓     | API key for the ZenPay merchant account.                                                                                                                                       |
| `ZENPAY_USERNAME`               |    ✓     | Hashed into the SHA3-512 fingerprint; never leaves this backend.                                                                                                               |
| `ZENPAY_PASSWORD`               |    ✓     | Hashed into the SHA3-512 fingerprint; never leaves this backend.                                                                                                               |
| `TOKEN_SECRET`                  |    ✓     | Root secret every token type (`checkoutToken`, `sessionToken`, the `?t=` return/status token) derives its own signing key from. Must be ≥32 bytes or session creation fails. Generate with `openssl rand -hex 32`. Rotating it invalidates every outstanding token. |
| `ALLOWED_APP_ORIGIN`            |          | Browser origin for CORS (default `http://localhost:3000`).                                                                                                                     |
| `APP_RETURN_URI_WEB`            |          | HTTPS URI the return broker redirects web clients to (default `https://localhost:3000/`).                                                                                      |
| `ZENPAY_ALLOWED_CHECKOUT_HOSTS` |          | Comma-separated allowlist of checkout URL hosts (default `pay.sandbox.travelpay.com.au`).                                                                                      |
| `CHECKOUT_STATUS_TTL_MINUTES`   |          | How long to keep in-memory attempts before purging (default `60`).                                                                                                             |

### 3. Run the Server

**From the repo root** (recommended — see [scripts/README.md](../scripts/README.md)):

```pwsh
./scripts/run-backend.ps1
```

**Or directly with Dart:**

```bash
cd ../example/backend && dart run bin/server.dart
```

The server listens on `0.0.0.0:<PORT>` and shuts down cleanly on `Ctrl+C`.

---

## API Endpoints

This is a **minimal demo backend** (see the doc comment atop `server_app.dart`)
— no merchant login, no static Bearer token, no session or retry concept.
Checkout creation is a two-step token/exchange model, bounded by per-IP rate
limiting and optional Firebase App Check instead of authentication; status
lookup and the return are gated on a signed `?t=` callback URL token. Full
detail, including the identity model and security posture:
[example/backend/README.md](../example/backend/README.md).

| Method | Path                              |          Auth           | Description                                                                              |
| :----- | :--------------------------------- | :----------------------: | :------------------------------------------------------------------------------------------ |
| `POST` | `/api/v1/checkout/token`          |                          | Step 1 — prepares a checkout, resolves the trusted amount, returns a signed `checkoutToken`. Requires `Idempotency-Key` header (16–128 chars); anonymous but rate-limited per IP and App-Check-gated. |
| `POST` | `/api/v1/checkout/exchange`       | `Bearer <checkoutToken>` | Step 2 — verifies the token, builds (or, on replay, reuses) the ZenPay checkout URL.     |
| `GET`  | `/api/v1/sessions?t=...`          | `t` token                | Retrieves authoritative payment status for the one attempt named by the verified token.  |
| `POST` | `/api/v1/callbacks`               |                          | ZenPay server-to-server webhook. Verifies SHA3-512 `ValidationCode`.                     |
| `GET`  | `/return?t=...`                   | `t` token                | Browser redirect broker — 303 for mobile/web.                                            |
| `GET`  | `/.well-known/assetlinks.json`    |                          | Android App Links verification file.                                                     |
| `GET`  | `/.well-known/apple-app-site-association` |                  | iOS Universal Links verification file.                                                   |

There is no `POST` endpoint that mints a fresh ZenPay checkout URL from a
single anonymous request, and no `sessionToken`, `sessionId`, or retry
endpoint — those were removed from the reference backend's design; see
[example/backend/README.md § Checkout Identity Model](../example/backend/README.md#checkout-identity-model).

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

1. **Client prepares a checkout** → backend validates the request, resolves the trusted amount, mints a fresh MUPID/timestamp, and returns a signed `checkoutToken` — no ZenPay URL yet.
2. **Client exchanges the token** → backend verifies it, builds the SHA3-512 fingerprint and launch URL locally (no outbound call to ZenPay), and returns the checkout URL. Replaying the same `checkoutToken` resolves to the same attempt, never a new one.
3. **Client opens the checkout URL** → customer pays on ZenPay's hosted page.
4. **ZenPay calls back** → backend verifies the `ValidationCode` hash in constant time and updates the attempt — the sole authoritative source of payment status.
5. **Browser returns** → the signed `?t=` token authorizes the redirect; this is provisional, not proof of payment.
6. **Client polls status** → backend returns the authoritative state from the verified callback, gated on the same `?t=` token.
7. **No retry endpoint** — if checkout fails, is dismissed, or times out, pressing Pay again is simply a fresh `POST /checkout/token` → `/checkout/exchange`, with a new, unrelated MUPID and checkout URL.

---

## Security Model

- **SHA3-512 fingerprint** — every launch URL carries a per-transaction fingerprint computed from `apiKey|username|password|mode|amountCents|mupid|timestamp`. ZenPay recomputes this on receipt; a mismatch rejects the request.
- **SHA3-512 callback validation** — incoming callbacks carry a `validationCode` hash over the same fields plus the transaction reference. The SDK recomputes and compares in constant time (`constantTimeHexEqual`).
- **Timing-safe comparisons** — all cryptographic comparisons use constant-time digest equality to prevent timing attacks.
- **No outbound calls at launch** — the checkout URL is constructed entirely from query parameter serialization; there is no HTTP call to ZenPay at session creation time.
- **Callback URL tokens gate status/return access** — the example backend mints an HMAC-SHA3-512 signed `?t=<token>` at checkout-exchange time and requires it on `GET /api/v1/sessions` and `GET /return`; it never gates `POST /api/v1/callbacks` acceptance, which is authenticated by `ValidationCode` alone.
- **No sensitive data in logs** — passwords, card numbers, CVVs, and secrets are never logged. Only payment identifiers, event types, status codes, and non-sensitive business fields appear in structured JSON logs. Full tokens (`checkoutToken`, `sessionToken`, `t`) are never logged either — see [example/backend/README.md § Security Model](../example/backend/README.md#security-model) for the full posture, including the anonymous checkout-creation boundary's rate limiting and retry policy.

---

## Development

### Verification Pipeline

Run before every commit:

```pwsh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
Push-Location ../example/backend
dart analyze --fatal-infos
dart test
Pop-Location
```

Or as a single command:

```pwsh
dart format --output=none --set-exit-if-changed . ; dart analyze --fatal-infos ; dart test ; Push-Location ../example/backend ; dart analyze --fatal-infos ; dart test ; Pop-Location
```

Or, from the **repository root**, across every package at once (see [../CLAUDE.md](../CLAUDE.md)):

```pwsh
melos run format
melos run analyze
melos run test
```

### Code Quality

- **Strict analysis**: `strict-casts`, `strict-inference`, `strict-raw-types` — no untyped `dynamic`.
- **Public API docs enforced**: `public_member_api_docs: error` on the core package.
- **Dead code is an error**: unused imports, private members, and locals are compiler errors.
- **Style**: `final` locals, constructors first, `dart format` with the repo's 160-character `page_width`.

### Testing

The core package tests cover:

- Fingerprint generation across all four modes
- Callback verification (valid, malformed, rejected) for payment, custom payment, preauth, and tokenise modes
- Checkout URL construction and validation
- Callback URL token minting, verification, expiry, and tamper detection
- Dollar-to-cents conversion edge cases
- Constant-time comparison correctness

The reference backend tests (`../example/backend/test/`) cover:

- Health endpoint configuration reporting
- Checkout-token preparation with idempotency enforcement (create, replay, conflict) and product/mode validation
- Checkout-exchange replay (same token → same attempt, no duplicate) and per-IP rate limiting
- Retry-token policy (terminal-session rejection, max-attempts, minimum interval) and session-token authorization
- Checkout/session token issuance, verification, expiry, tamper, and cross-scope confusion rejection
- Callback URL token issuance and verification (missing/forged/expired `t`)
- Callback signature verification and status mapping
- Return broker redirect behavior (mobile App Link, web)

---

## License

See [LICENSE](LICENSE).
