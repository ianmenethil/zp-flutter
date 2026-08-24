# scripts — Repo-Maintenance Dart Scripts

Standalone Dart scripts, each run directly with `dart run scripts/<name>.dart`. Not a
published package and has no `pubspec.yaml` of its own — resolves against the repo root's
pub workspace, same as `cli.dart`. Distinct from `cli.dart` at the repo root: `cli.dart` is
the everyday dev-loop entrypoint (run the server, run the app, tunnels, Docker, releases);
these two scripts are narrower, lower-level tools that `cli.dart` itself shells out to at
the right moments rather than something you'd normally run standalone.

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview; see `cli.dart --help` for
  the commands that wrap these scripts.
- **[docker](../docker/CLAUDE.md)** — the Dockerfiles whose throwaway `workspace:` list
  must be updated by hand if this repo's real root workspace ever changes.

## Files

- **[apply_platform_config.dart](apply_platform_config.dart)** — patches
  `example/app/android/app/src/main/AndroidManifest.xml` and
  `example/app/ios/Runner/Runner.entitlements` (+ `Info.plist`, `project.pbxproj`) with App
  Link / Universal Link config for a given host, either passed via `--host <domain>` or
  read from `wrangler.jsonc`'s `vars.PUBLIC_BASE_URL` via `--from-wrangler`. Idempotent —
  re-running against the same host is a no-op. Exists because `flutter create` regenerates
  those platform folders, so the host can't be committed by hand into them directly.
  **`cli.dart`'s `_server()` calls this automatically whenever `PUBLIC_BASE_URL` changes**,
  pointing native config at the local tunnel host — so running `--server` without
  `--keep-url` silently switches Android/iOS back to the tunnel. Re-run with
  `--from-wrangler` to point native config at production again afterward. Both
  `AndroidManifest.xml`/`Runner.entitlements` hold exactly one host at a time, never both.
- **[apply_platform_config_test.dart](apply_platform_config_test.dart)** — exercises
  `patchAndroid`/`patchIos`/`hostFromWrangler` directly against temp-directory fixtures
  (they're `public` specifically so tests can call them without going through `main`).
- **[sync_package_examples.dart](sync_package_examples.dart)** — copies whatever `git`
  tracks (or would track, respecting each source's own `.gitignore`, via
  `git ls-files --others --exclude-standard --cached`) out of `example/backend` and
  `example/app` into `zenpay_dart/example/`, `zenpay_flutter/example/backend/`, and
  `zenpay_flutter/example/app/`. Exists because `dart pub publish` bundles each package's
  own `example/` for its pub.dev score, and a monorepo-root `example/` sibling directory
  is never included in an individual package's publish archive. `example/backend` and
  `example/app` are the single source of truth — never hand-edit any of the three
  destinations; they're fully replaced on every run. After copying, it also: strips the
  copied `pubspec.yaml`'s `resolution: workspace` line (the destination isn't a declared
  workspace member, so left in place it breaks `dart pub get` for the *entire* monorepo);
  writes a generated `pubspec_overrides.yaml` pointing each copy's SDK dependency at the
  in-repo package path (the committed version constraint, e.g. `zenpay_dart: ^0.1.0`,
  can't resolve before that package's first real pub.dev publish); and repoints the copied
  `analysis_options.yaml`'s `include:` from the monorepo root's file (unreachable
  standalone) to `package:lints/recommended.yaml` (a dependency every copy's own
  `pubspec.yaml` actually declares). Run manually with
  `dart run cli.dart --sync-examples`, or automatically before every
  `--release:dart:*`/`--release:flutter:*`.

## Verification

Run from the **repository root**:

```pwsh
melos run test
```

Or directly:

```pwsh
dart test scripts/apply_platform_config_test.dart
dart run scripts/apply_platform_config.dart --help
dart run scripts/sync_package_examples.dart --help
```
