# ZenPay SDK Monorepo Guidelines

This repository is a unified **Melos Monorepo** containing the complete ZenPay Dart and Flutter ecosystem. It is designed to provide secure, robust, and strongly-typed tools for merchants integrating ZenPay Hosted Checkout.

See [README.md](README.md) for the repo overview and quick start. `AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

## Related Guides

Each package has its own `CLAUDE.md` (also readable as `AGENTS.md`, a symlink to the same file) with package-specific detail:

1. **[zenpay_dart/CLAUDE.md](zenpay_dart/CLAUDE.md)** ([README](zenpay_dart/README.md)): Pure Dart SDK. Server-side logic, cryptography (SHA3-512, HMAC), token validation, URL construction.
2. **[zenpay_flutter/CLAUDE.md](zenpay_flutter/CLAUDE.md)** ([README](zenpay_flutter/README.md)): Flutter client SDK. UI orchestration, deep-link return handling, URL launching, client-side lifecycle.
3. **[zenpay_embedded/CLAUDE.md](zenpay_embedded/CLAUDE.md)** ([README](zenpay_embedded/README.md)): Optional embedded in-app WebView presentation, depends on `zenpay_flutter`. Opt-in only, not the default.
4. **[example/CLAUDE.md](example/CLAUDE.md)** ([README](example/README.md)): Reference integration — a mock merchant backend ([example/backend/CLAUDE.md](example/backend/CLAUDE.md)) and a test mobile app ([example/app/CLAUDE.md](example/app/CLAUDE.md)) demonstrating the full end-to-end flow.
5. **[docker/CLAUDE.md](docker/CLAUDE.md)**: Local Docker Compose stack and the Cloudflare Container images built from the same example app.
6. **[scripts/CLAUDE.md](scripts/CLAUDE.md)**: Repo-maintenance Dart scripts (`apply_platform_config.dart`, `sync_package_examples.dart`) invoked by `cli.dart`.

---

## Repo-Root Source Guide

### `cli.dart`

**Overview:** Single cross-platform dev launcher — one mode runs as a live, attached process (Ctrl+C stops it; logs stream to this terminal, nothing runs detached). Findable and runnable at any depth in the repo. Replaces what would otherwise be separate `run-*.ps1`/`.sh` scripts per platform.

- **`main(List<String> arguments)`**: Parses exactly one `--<mode>` flag plus shared options (`--device`, `--public-base-url`, `--keep-url`, `--skip-certs`, `--url`) and dispatches to the matching mode function; `-h`/`--help` prints full usage.
- **`_bootstrap(...)`**: First-run setup on a fresh clone, leaving nothing to hand-edit — resolves the pub workspace (`dart pub get`), creates `example/backend/.env` and `example/app/.env` from their `.example` templates, prompts for each value the backend refuses to start without (`ZENPAY_MERCHANT_CODE`, `ZENPAY_API_KEY`, `ZENPAY_USERNAME`, `ZENPAY_PASSWORD`, `TOKEN_SECRET` — Enter keeps what's already set, and a blank `TOKEN_SECRET` is auto-generated), generates the local mkcert TLS cert `example/app` needs for the web return flow (`--skip-certs` to skip; `mkcert -install` failing against a JDK/JBR's own cacerts — e.g. Android Studio's bundled one under Windows' admin-protected `Program Files` — warns and continues rather than failing the bootstrap, since only the system trust store it checks first actually matters here), and writes `example/backend/well_known/assetlinks.json` for this machine. Deliberately does **not** prompt for `PUBLIC_BASE_URL` — `_server` owns that, and it changes every time a tunnel restarts.
- **`_promptEnvValue(...)`**: One interactive `KEY=value` prompt against a `.env` file — masks secrets via `_maskSecret`, treats Enter as "keep", and returns the value in force afterwards. Shared by `_bootstrap` and `_tunnel`, which previously hand-rolled the same read/prompt/rewrite logic separately. `_server` deliberately keeps its own: it also derives `APP_RETURN_URI_MOBILE` and re-syncs native config, so it is not a plain key prompt.
- **`upsertEnvValue(...)`** / **`envValuePattern(String key)`** / **`generateTokenSecret()`** / **`keytoolCandidates()`** / **`resolveKeytool({List<String>? candidates})`** / **`androidApplicationId(String root)`**: The pure seams behind the above, public — like `scripts/apply_platform_config.dart`'s helpers — purely so `cli_test.dart` can drive them without a stdin prompt or `main`'s `exit`. `resolveKeytool` takes an injectable candidate list so the not-found branch is testable on a machine that does have a JDK.
- **`_debugKeystoreSha256()`** / **`_ensureAppLinks(String root)`**: Read this machine's Android debug signing fingerprint via `keytool`, and write `example/backend/well_known/assetlinks.json` from it plus the app's `applicationId`. Same class of artifact as the mkcert cert — derived from local state, different on every machine, gitignored rather than committed. Without it Android's `autoVerify` fails and the mobile checkout return opens a browser instead of the app. Missing `keytool` warns and continues rather than failing the bootstrap.

### `cli_test.dart`

**Overview:** Fixture-based tests for `cli.dart`'s pure helpers — the `.env` upsert (replace / fill-blank / append / no prefix-collision), `TOKEN_SECRET` shape and uniqueness, `keytool` candidate ordering and the not-found branch, and `applicationId` extraction from both the Kotlin and Groovy Gradle forms. Not reached by `melos run test`, which filters on packages with a `test/` directory; run it directly with `dart test cli_test.dart`.

- **`main()`**: Test suite entrypoint; groups mirror the four public seams listed above.
- **`_server(...)`**: Runs `example/backend` (`dart run bin/server.dart`). Prompts for and persists `PUBLIC_BASE_URL` (unless `--keep-url`), propagates the derived mobile return URI into `example/app/.env`, and always re-syncs native Android/iOS App Link config to match.
- **`_syncNativeAppLinkConfig(String root)`**: Points `AndroidManifest.xml`/`Runner.entitlements` at whatever host `example/backend/.env`'s `PUBLIC_BASE_URL` currently names, via `scripts/apply_platform_config.dart`. No-op if `.env` or the Android project don't exist yet.
- **`_android(...)`**: Runs `example/app` on Android — warns (non-fatal, via `_isPortOpen`) if nothing is listening on `:7000` yet, then `adb reverse tcp:7000` then `flutter run`; `--android-webview` mode passes `-t lib/embedded_demo_main.dart` to launch the `zenpay_embedded` WebView demo entrypoint instead of the default `lib/main.dart`.
- **`_ios(...)`**: Runs `example/app` on iOS. Hard-errors off Windows/Linux — Flutter cannot build iOS there at all.
- **`_web(String root)`**: Runs `example/app` on Chrome, serving over TLS via the mkcert cert when present (falls back to plain HTTP with a warning otherwise, since the SDK requires an `https` return URI).
- **`_stream({String? deviceId})`**: Mirrors a connected Android device's screen via `scrcpy`; independent of every other mode and the repo itself.
- **`_tunnel(String root)`**: Runs the named `cloudflared` tunnel using a durable token persisted in `example/backend/.env`'s `CLOUDFLARE_TUNNEL_TOKEN` (prompts to keep or replace it).
- **`_quickTunnel(String root, {String? url})`**: Runs an ephemeral `cloudflared tunnel --url` needing no Cloudflare account — prints a random `https://*.trycloudflare.com` URL to paste into `--server --public-base-url=<url>`.
- **`_dockerBuild(String root)`** / **`_dockerRun(String root)`** / **`_dockerRebuild(String root)`**: Build, run, and (stop + rebuild fresh +) run the combined backend/frontend Docker Compose stack (`docker/local/docker-compose.yml`) on ports 7000/8080, starting the `cloudflared` tunnel alongside it when a token is configured.
- **`_cfDeploy(String root)`**: Deploys the Cloudflare Workers backend and Containers via `npm run cf:deploy`.
- **`_syncExamples(String root)`**: Regenerates `zenpay_dart/example` and `zenpay_flutter/example` from `example/backend`/`example/app` via `scripts/sync_package_examples.dart`. Runnable standalone (`--sync-examples`) or automatically before every `--release-*`.
- **`_check(String root)`**: Runs every check CI (`codemagic.yaml`) and the pre-commit hook (`lefthook.yml`) require, across the *whole* tree rather than just staged files — format, `melos run analyze`, `melos run test`/`test:dart`, `scripts/check_claude_md.dart`, and the three static PCI regression guards (no JS bridge, WebView teardown, no host allowlist on WebView navigation), re-implemented in pure Dart rather than shelling out to `grep`. Reports every step's outcome, then — for any that failed — reprints that step's captured output (or a synthesized reason, for the static guards) under a final "Why" section, so the cause is visible without scrolling back through everything else that ran; exits non-zero if anything failed.
- **`_dartFilesContainAny(String dirPath, List<String> needles)`** / **`_fileContainsAny(String filePath, List<String> needles)`** / **`_fileContainsAll(String filePath, List<String> needles)`**: The text-search primitives behind `_check`'s three static guards — kept in sync with `lefthook.yml`'s equivalent `grep` commands by hand, since nothing generates one from the other.
- **`_release(String root, {required String package, required String bump})`**: Bumps `zenpay_dart` or `zenpay_flutter` to the next minor/major stable version via `melos version` (no git tag/commit), re-syncs its example, and validates with `dart pub publish --dry-run`. Never commits, tags, or actually publishes — those stay manual.

---

## 🛠️ Monorepo Tooling (Melos)

We use [Melos](https://melos.invertase.dev) to manage dependencies and run verification commands across all packages simultaneously.

### Rules:

- **Never** run `flutter pub get` manually in subdirectories.
- Always use `melos bs` from the root to resolve the Dart pub workspace — sibling packages link via ordinary version constraints (`resolution: workspace`), not `path:` overrides.
- To run anything (server, android/ios/web app, tunnels, docker, releases), use
  `dart run cli.dart --help` for the full mode list — not raw `flutter run`.
- `zenpay_dart/example/` and `zenpay_flutter/example/` are generated by
  `dart run cli.dart --sync-examples` from `example/backend`/`example/app`.
  Never hand-edit them — edit the source and re-sync.

### CI

Two pipelines run on every push/PR: GitHub Actions (`.github/workflows/pr_check.yaml`) runs
format/analyze/test only; Codemagic (`codemagic.yaml`) runs the same checks plus Android/iOS/Web
debug builds. `lefthook`'s pre-commit gate enforces a staged-files-scoped subset of the same
checks locally before either one ever runs — `dart run cli.dart --check` runs everything both
require, across the whole tree, without waiting for a push.

---

## Verification

Run these commands from the repository root to verify your changes across all packages:

```pwsh
melos bs
melos run format
melos run analyze
melos run test
melos run test:dart
```

Or `dart run cli.dart --check` after `melos bs`, which runs all of the above plus
`scripts/check_claude_md.dart` and the three PCI regression guards in one pass, and reports
why anything that fails actually failed.

Also: `dart run scripts/check_claude_md.dart` — checks every `CLAUDE.md` in the repo against
`scripts/claude_md_template.md` (required sections, per-file coverage). See
`scripts/CLAUDE.md`.

---

## 🚨 Global Strictness & Code Quality

1. **Strict Type Safety**: All packages enforce `strict-casts`, `strict-inference`, and `strict-raw-types`. Avoid `dynamic` at all costs.
2. **Public API Documentation**: Any exported symbol in `lib/` for any package must have comprehensive dartdoc (`///`) explaining its purpose and failure modes.
3. **No Unused Code**: Clean up unused imports, variables, and private members immediately.
