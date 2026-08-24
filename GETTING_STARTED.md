# Getting Started

See [README.md](README.md) for the repo overview and [ARCHITECTURE.md](ARCHITECTURE.md) for the integration diagram. This guide walks a new clone through prerequisites, running the stack locally, every `cli.dart` mode, and verifying changes.

---

## 1. Prerequisites

| Needed for | Install |
| :--- | :--- |
| Everything | [Dart SDK](https://dart.dev/get-dart) `^3.13.0` and [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel) — Flutter bundles a compatible Dart, so installing Flutter alone covers both. |
| Everything | [Melos](https://melos.invertase.dev) `^8.3.0`: `dart pub global activate melos`. This repo is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) (see [`pubspec.yaml`](pubspec.yaml)); Melos drives the multi-package scripts (`melos bs`, `melos run test`, etc.). |
| `--bootstrap`'s local TLS cert | [mkcert](https://github.com/FiloSottile/mkcert) — needed for `--web`'s HTTPS return flow, and for `--docker-run`/`--docker-rebuild` (the Docker frontend also terminates TLS with this cert). Pass `--skip-certs` to `--bootstrap` to skip it. |
| `--android` / `--android-webview` | Android Studio + SDK, `adb`, and a device or emulator. |
| `--ios` | Xcode + CocoaPods, **macOS only** — `cli.dart` hard-errors on Windows/Linux. |
| `--tunnel` / `--quick-tunnel` | [`cloudflared`](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/). Needed to test anything beyond launching checkout — ZenPay's callback is server-to-server and cannot reach `localhost`. |
| `--docker-build` | Docker + Docker Compose only. |
| `--docker-run` / `--docker-rebuild` | Docker + Docker Compose, **plus**: `example/backend/.env` (from `--bootstrap`), the mkcert TLS cert above, and a GCP `example/backend/service-account.json` you supply yourself (nothing in this repo generates it — see §3 Docker). |
| `--cf-deploy` | Node/npm and a Cloudflare account with access to this project's Worker — maintainers only. |
| `--stream` | [`scrcpy`](https://github.com/Genymobile/scrcpy). |

You do not need every row on day one — only Dart/Flutter/Melos to get the server and app running. Add the rest as you reach the step that needs them.

---

## 2. First run, step by step

Run these from the **repository root**, in order.

### 2.1 Clone and bootstrap

```pwsh
git clone <this repo>
cd zp-flutter-sdk
dart run cli.dart --bootstrap
```

`--bootstrap` does three things on a fresh clone:

1. Resolves the pub workspace (`dart pub get` at the root — links every workspace member to its siblings via ordinary version constraints; a `path:` dependency is actually rejected once a package is a workspace member).
2. Creates `example/backend/.env` and `example/app/.env` from their `.env.example` templates, if they don't already exist.
3. Generates the local `mkcert` TLS cert `example/app` needs for the web checkout-return flow (skip with `--skip-certs`).

### 2.2 Fill in credentials

Open `example/backend/.env` and set the fields the server needs to create a session:

| Variable | What it is |
| :--- | :--- |
| `ZENPAY_MERCHANT_CODE`, `ZENPAY_API_KEY`, `ZENPAY_USERNAME`, `ZENPAY_PASSWORD` | Credentials for a ZenPay sandbox or production merchant account (see [`zenpay_dart/README.md`](zenpay_dart/README.md#prerequisites)). Not included in this repo — this doc doesn't say where to request one; ask whoever owns your ZenPay merchant relationship. |
| `TOKEN_SECRET` | Any random string **≥ 32 bytes**. Generate one with `openssl rand -hex 32`. |

The server refuses to start session creation without these — see `sessionConfigurationErrors` in [`example/backend/lib/src/config.dart`](example/backend/lib/src/config.dart). Everything else in `.env.example` has a working default for local dev.

### 2.3 Start the backend

```pwsh
dart run cli.dart --server
```

Starts `example/backend` on `:7000`. Prompts for `PUBLIC_BASE_URL` (unless `--keep-url`) and propagates whatever you enter into `example/app/.env` and the native Android/iOS App Link config automatically. `localhost` works for launching checkout; you need a real public HTTPS URL (§3, Tunnels) once you want ZenPay's server-to-server callback to reach you.

### 2.4 Start the app

In a **second terminal**, from the repo root:

```pwsh
dart run cli.dart --android   # or --ios / --web
```

Starts `example/app`, talking to the backend from 2.3. `--android` sets up `adb reverse tcp:7000` for you first.

### 2.5 What success looks like

The app opens on a transaction-mode picker (Make Payment / Tokenise / Custom Payment / Preauthorization). Fill in the form, tap Pay, and you should land on ZenPay's hosted sandbox checkout page. That confirms steps 2.1–2.4 are wired correctly, even without a tunnel.

To see the full round trip — checkout completing and the app receiving a verified result — you need `PUBLIC_BASE_URL` pointed at a real public URL ZenPay can call back to. That's what §3's tunnel modes are for.

---

## 3. Full `cli.dart` mode reference

Every mode runs as a **live, attached process** — `Ctrl+C` stops it, logs stream to your terminal, nothing runs in the background. Run `dart run cli.dart --help` any time for the authoritative list; this table adds the "when would I use this" a bare `--help` doesn't.

### Core dev loop

| Mode | What it does | When to use it |
| :--- | :--- | :--- |
| `--bootstrap` | First-run setup (§2.1). | Once per fresh clone. |
| `--server` | Runs `example/backend` on `:7000`. | Every session, before the app. |
| `--android` | Runs `example/app` on Android (`adb reverse` first). | Testing on Android. |
| `--android-webview` | Runs the `zenpay_embedded` in-app WebView demo on Android (`lib/embedded_demo_main.dart`). | Testing the embedded WebView presenter instead of the default Custom Tab flow. |
| `--ios` | Runs `example/app` on iOS. macOS only. | Testing on iOS. |
| `--web` | Runs `example/app` on Chrome, over HTTPS via the mkcert cert when present. | Testing on web. |
| `--stream` | Mirrors a connected Android device's screen via `scrcpy`. | Screen-recording or presenting a demo; independent of everything else. |

Shared options: `--device=<id>` (Android/iOS/stream device selection), `--public-base-url=<url>` and `--keep-url` (control the `--server` prompt), `--skip-certs` (`--bootstrap`).

### Tunnels — exposing your local backend

ZenPay's callback is server-to-server; it cannot reach `localhost`. To test the full flow (or App Link verification, which needs a publicly fetchable `/.well-known/`), your backend needs a real HTTPS URL.

| Mode | What it does | When to use it |
| :--- | :--- | :--- |
| `--quick-tunnel` | Ephemeral `*.trycloudflare.com` URL via `cloudflared tunnel --url`. No Cloudflare account needed. | Quickest way to get a public URL for a one-off test session. |
| `--tunnel` | Runs your own **named** `cloudflared` tunnel, using a token saved in `example/backend/.env`'s `CLOUDFLARE_TUNNEL_TOKEN`. | A stable URL across restarts (needed for a real App Link / Universal Link that must resolve consistently). |

After starting either, run `--server` (or re-run it) and paste the printed URL when prompted for `PUBLIC_BASE_URL` — that also re-syncs the native Android/iOS App Link config automatically. See [example/README.md § Local dev vs. production host](example/README.md#local-dev-vs-production-host) for how that config switches between tunnel and production.

### Docker

| Mode | What it does | When to use it |
| :--- | :--- | :--- |
| `--docker-build` | Builds the backend + frontend images (`docker/local/docker-compose.yml`). No `.env`, cert, or service-account file needed — it only builds images. | First time, or after a Dockerfile change. |
| `--docker-run` | Runs both via Compose on `:7000`/`:8080`, plus the tunnel if `.env` has a token. | Running the stack without `flutter run`. |
| `--docker-rebuild` | Stops, removes images, rebuilds fresh, and runs (`--docker-build` + `--docker-run`). | Docker state looks stale or broken. |

`--docker-run`/`--docker-rebuild` refuse to start unless **all** of these exist first — `cli.dart` checks and hard-errors with the specific one missing:

- `example/backend/.env` — same file `--bootstrap` creates.
- `example/app/localhost+2.pem` + `-key.pem` — the mkcert cert from `--bootstrap` (or run `mkcert localhost 127.0.0.1 ::1` in `example/app` yourself). The frontend container serves `https://localhost:8080` and terminates TLS with this exact cert (`docker/local/Dockerfile.frontend`) — the SDK's return URI must be HTTPS, same reason `--web` needs it.
- `example/backend/service-account.json` — a GCP service account key for reCAPTCHA Enterprise verification. Unlike the cert, **nothing in this repo generates this file** — `docker-compose.yml` bind-mounts it unconditionally, so you must supply your own key (or remove that service's `volumes:` line if you don't need reCAPTCHA enforcement locally).

### Cloudflare / production (maintainers)

| Mode | What it does | When to use it |
| :--- | :--- | :--- |
| `--cf-deploy` | Deploys the Cloudflare Workers backend and Containers (`npm run cf:deploy`). | Shipping a change to the live Worker. Needs Cloudflare account access. |

To point native Android/iOS config at the deployed production host instead of a local tunnel, without hand-editing `AndroidManifest.xml`/`Runner.entitlements`:

```pwsh
dart run scripts/apply_platform_config.dart --from-wrangler
```

This reads the canonical host straight out of [`wrangler.jsonc`](wrangler.jsonc).

### Examples & releases (package maintainers)

| Mode | What it does | When to use it |
| :--- | :--- | :--- |
| `--sync-examples` | Regenerates `zenpay_dart/example/` and `zenpay_flutter/example/` from `example/backend`/`example/app` (§4 below). | After changing `example/backend` or `example/app`, before a release. |
| `--release:dart:minor` / `--release:dart:major` | Bumps `zenpay_dart`'s version, re-syncs its example, validates with `dart pub publish --dry-run`. Never commits, tags, or publishes. | Preparing a `zenpay_dart` release. |
| `--release:flutter:minor` / `--release:flutter:major` | Same, for `zenpay_flutter`. | Preparing a `zenpay_flutter` release. |

---

## 4. Verifying changes

Run from the repo root, independent of the steps above:

```pwsh
melos bs              # resolves the pub workspace, linking sibling packages — never `flutter pub get`/`dart pub get` in a subdirectory
melos run format
melos run analyze
melos run lint
melos run test
```

Also: `dart run scripts/check_claude_md.dart` — checks every `CLAUDE.md` in the repo against `scripts/claude_md_template.md`.

---

## 5. How `zenpay_dart/example/` and `zenpay_flutter/example/` work

Neither directory is hand-written or checked into git. `example/backend/` and
`example/app/` are the single source of truth; `scripts/sync_package_examples.dart`
copies whatever `git` tracks (or would track, respecting each source's own
`.gitignore`) out of them into:

- `zenpay_dart/example/` ← `example/backend`
- `zenpay_flutter/example/backend/` ← `example/backend`
- `zenpay_flutter/example/app/` ← `example/app`

`.env`, `build/`, `.dart_tool/`, and internal `CLAUDE.md`/`AGENTS.md` guideline
files are never copied. All three destinations are gitignored and fully
replaced on every run — never edit them directly, edit
`example/backend`/`example/app` instead.

This exists because `dart pub publish` bundles each package's own `example/`
folder for its pub.dev score, and a monorepo-root `example/` sibling directory
is never included in an individual package's publish archive. Run it manually
with:

```pwsh
dart run cli.dart --sync-examples
```

It also runs automatically before every `--release:dart:*`/`--release:flutter:*`.
**Known issue:** `zenpay_dart/example/` and `zenpay_flutter/example/` are
currently also excluded from the actual `dart pub publish` archive by the same
`.gitignore` rule that keeps them out of git — confirmed via `dart pub publish
--dry-run`. Resolving this (un-ignoring the generated content, or committing a
small hand-written example instead) is still an open decision.
