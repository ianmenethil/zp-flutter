# example/app

Reference Flutter client for the combined ZenPay example: fetches a checkout
session from [`example/backend`](../backend/README.md), presents ZenPay
Hosted Checkout via [`zenpay_flutter`](../../zenpay_flutter/README.md), and
handles the return. Depends on `zenpay_flutter`, resolved to the local
package by the root Dart pub workspace (not a `path:` dependency).

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) (`AGENTS.md` here is a
symlink to it). Combined example overview: [../README.md](../README.md).

---

## Quick Start

`example/backend` must already be running (`dart run cli.dart --server`).
From the **repository root**:

```pwsh
dart run cli.dart --android     # picks the adb device, sets up adb reverse
dart run cli.dart --ios         # macOS + Xcode only
dart run cli.dart --web         # Chrome at https://localhost:3000, needs a local TLS cert (--bootstrap)
```

Configuration is `.env` (copy from `.env.example`) — must agree with
`example/backend/.env`: the SDK compares the return URI exactly (scheme,
host, port, path) and rejects a mismatch rather than ignoring it.

| Variable                 | Used on       | Description                                                                          |
| :------------------------ | :------------- | :-------------------------------------------------------------------------------------- |
| `BACKEND_BASE_URL`        | all            | Where `example/backend` listens. Android reaches it via `adb reverse` (handled by `cli.dart --android`). |
| `ALLOWED_CHECKOUT_HOSTS`  | all            | Hosts a checkout URL may point at — must match backend's `ZENPAY_ALLOWED_CHECKOUT_HOSTS`. |
| `APP_RETURN_URI_WEB`      | web            | HTTPS return URI for web checkouts (default `https://localhost:3000/`).             |
| `APP_RETURN_URI_MOBILE`   | Android, iOS   | Public HTTPS host serving `/.well-known/` — never `localhost`; the OS fetches those files from the internet. |

---

## Scope

- `lib/features/checkout/services/checkout_service.dart` only talks to
  `example/backend` — it never builds a checkout URL and never touches ZenPay
  credentials directly.
- `lib/features/checkout/ui/` is demonstration UI; visual design is the
  project owner's call, not invented here.
- Any outcome from `zenpay_flutter` is provisional — this app always confirms
  final status against the backend before showing success.

See [CLAUDE.md](CLAUDE.md) for the full rules.

---

## Related Guides

- **[CLAUDE.md](CLAUDE.md)** — Scope, responsibilities, provisional-status rule.
- **[../../zenpay_flutter/README.md](../../zenpay_flutter/README.md)** — The SDK this app is built on.
- **[../backend/README.md](../backend/README.md)** — The server this app talks to.
