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

From the **repository root**, using [`cli.dart`](../cli.dart)
(`dart run cli.dart --help` for the full mode list):

```pwsh
dart run cli.dart --bootstrap   # once per machine — TLS cert for web checkout
dart run cli.dart --server      # start the backend first, on :7000
dart run cli.dart --android     # then the app — or --ios / --web
```

### Local dev vs. production host

`example/backend/.env`'s `PUBLIC_BASE_URL` and the Android/iOS App Link
config (`AndroidManifest.xml` / `Runner.entitlements`) always name **one**
host at a time — local dev and production are never both live in the native
config simultaneously:

- **Local dev**: `dart run cli.dart --tunnel` (a saved named tunnel) or
  `--quick-tunnel` (an ephemeral `*.trycloudflare.com` URL) exposes your
  local backend. `dart run cli.dart --server` prompts for that tunnel's URL
  (unless `--keep-url`) and propagates it into both `.env` files.
  `--server`, `--android`, `--android-webview`, and `--ios` **all** then
  sync the native Android/iOS config to whatever `PUBLIC_BASE_URL` is
  currently in `example/backend/.env` — every time they run, not just on a
  change — via
  [`scripts/apply_platform_config.dart`](../scripts/apply_platform_config.dart).
  Never hand-edit `AndroidManifest.xml`/`Runner.entitlements` directly; edit
  `.env` instead and let the next run of any of those modes pick it up.
- **Production**: the deployed Cloudflare Worker's domain lives in
  [`wrangler.jsonc`](../wrangler.jsonc) (deploy with `dart run cli.dart
  --cf-deploy`). To point native Android/iOS config at production instead of
  the local tunnel:
  ```pwsh
  dart run scripts/apply_platform_config.dart --from-wrangler
  ```

See [`backend/well_known/README.md`](backend/well_known/README.md) for why
these files must always agree on one host.

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
