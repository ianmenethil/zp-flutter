# ZenPay Combined Example

Runnable, end-to-end demonstration of the ZenPay Hosted Checkout flow using
both published SDKs together.

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) — read this before
changing either half of the example. `AGENTS.md` here is a symlink to it.
Monorepo overview: [../README.md](../README.md).

---

## The Two-App Pattern

| App                                    | Path              | Depends on         | Role                                                                     |
| :--------------------------------------- | :------------------ | :-------------------- | :--------------------------------------------------------------------------- |
| [backend](backend/README.md)             | `example/backend/`  | `zenpay_dart`         | Shelf server. Holds API keys, creates sessions, builds launch URLs, verifies webhooks. |
| [app](app/README.md)                     | `example/app/`      | `zenpay_flutter`      | Flutter mobile/web app. Fetches a session, presents checkout, handles the return deep-link. |

Both depend on their SDK via a local Melos `path:` dependency — see the root
[`pubspec.yaml`](../pubspec.yaml) workspace list.

---

## Running It

From the **repository root** — see [scripts/README.md](../scripts/README.md)
for TLS setup, `.env` layout, and per-platform detail:

```pwsh
./scripts/run-backend.ps1     # start the backend first, on :7000
./scripts/run-android.ps1     # then the app — or run-ios.ps1 / run-web.ps1
```

---

## Look and Feel

UI/visual design for `example/app` is specified by the project owner, not
invented here — see [app/CLAUDE.md](app/CLAUDE.md). The example is meant to
stay minimal and focused on demonstrating the SDK integration.

---

## Related Guides

- **[../CLAUDE.md](../CLAUDE.md)** — Monorepo root guidelines.
- **[../zenpay_dart/CLAUDE.md](../zenpay_dart/CLAUDE.md)** — SDK the backend depends on.
- **[../zenpay_flutter/CLAUDE.md](../zenpay_flutter/CLAUDE.md)** — SDK the app depends on.
