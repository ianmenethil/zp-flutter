# Getting Started

See [README.md](README.md) for the repo overview and architecture. This guide covers cloning, running the stack locally, and verifying changes.

---

## 🚀 Setup

Requires the Flutter SDK and Dart SDK on `PATH` (`mkcert` too, if you want the
local TLS cert for web checkout). Run these **in order**:

1. Clone this repo.
2. ```pwsh
   dart run cli.dart --bootstrap
   ```
   Resolves the pub workspace, creates `example/backend/.env` and
   `example/app/.env` from their templates, and sets up the local TLS cert
   for web checkout.
3. Fill in your `ZENPAY_*` credentials in `example/backend/.env` — the
   server will not start without them.
4. ```pwsh
   dart run cli.dart --server
   ```
   Starts `example/backend` on `:7000`. Prompts for `PUBLIC_BASE_URL` and
   propagates it to `example/app/.env` and the native Android/iOS App Link
   config.
5. ```pwsh
   dart run cli.dart --android   # or --ios / --web
   ```
   Starts `example/app`, talking to the backend from step 4.

`dart run cli.dart --help` lists every other mode (named/quick tunnels,
Docker, Cloudflare deploy, release bumps). See
[example/README.md](example/README.md) for local dev vs. production hosts.

---

## ✅ Verifying changes

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces)
managed with [Melos](https://melos.invertase.dev) — see root
[`pubspec.yaml`](pubspec.yaml) for the workspace member list and Melos
script definitions. Run from the repo root, independent of the steps above:

```pwsh
melos bs              # links local path: deps across all packages
melos run format
melos run analyze
melos run lint
melos run test
```

**Never** run `flutter pub get` or `dart pub get` manually in a subdirectory — always bootstrap from the root with `melos bs`.

---

## 📦 How `zenpay_dart/example/` and `zenpay_flutter/example/` work

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
