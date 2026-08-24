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

## Source Guide

### `apply_platform_config.dart`

**Overview:** Patches the generated Android/iOS host projects
(`example/app/android/app/src/main/AndroidManifest.xml`,
`example/app/ios/Runner/Runner.entitlements` + `Info.plist`, `project.pbxproj`) with App
Link / Universal Link config for a given host, either passed via `--host <domain>` or read
from `wrangler.jsonc`'s `vars.PUBLIC_BASE_URL` via `--from-wrangler`. Idempotent —
re-running against the same host is a no-op. Exists because `flutter create` regenerates
those platform folders, so the host can't be committed by hand into them directly.
`cli.dart`'s `_server()` calls this automatically whenever `PUBLIC_BASE_URL` changes,
pointing native config at the local tunnel host — so running `--server` without
`--keep-url` silently switches Android/iOS back to the tunnel; re-run with
`--from-wrangler` to point native config at production again afterward. Both
`AndroidManifest.xml`/`Runner.entitlements` hold exactly one host at a time, never both.

- **`buildParser()`**: Builds the `--host`/`--from-wrangler`/`--root`/`--path` `ArgParser`;
  a top-level function so tests can exercise parsing without invoking `main` (which calls
  `exit`).
- **`main(List<String> arguments)`**: CLI entrypoint — requires exactly one of
  `--host`/`--from-wrangler`, then calls `patchAndroid` and `patchIos` for the resolved
  host and path.
- **`hostFromWrangler(String root)`**: Reads the production host out of `wrangler.jsonc`'s
  `vars.PUBLIC_BASE_URL`; public so tests can call it directly against a temp directory.
- **`patchAndroid(String root, String host, String path)`**: Patches `AndroidManifest.xml`
  with the App Link `<intent-filter>` and disables `flutter_deeplinking_enabled` so
  `app_links`' own return handler doesn't compete with Flutter's; rewrites the host/path in
  place on re-run rather than appending a duplicate filter. Public so tests can call it
  directly against a temp directory.
- **`patchIos(String root, String host)`**: Writes `Runner.entitlements` with the
  `applinks:$host` associated domain, adds `FlutterDeepLinkingEnabled` to `Info.plist`
  once, and adds `CODE_SIGN_ENTITLEMENTS` to the app target's `project.pbxproj` build
  settings while excluding `RunnerTests` (its own bundle identifier). Public so tests can
  call it directly against a temp directory.

### `apply_platform_config_test.dart`

**Overview:** Fixture-based tests exercising `buildParser`, `hostFromWrangler`,
`patchAndroid`, and `patchIos` directly against temp-directory fixtures — those four are
`public` specifically so tests can call them without going through `main`.

- **`main()`**: Test suite entrypoint; groups cover argument-parsing defaults, extracting
  the host from `wrangler.jsonc`, inserting/idempotently rewriting the Android intent
  filter, and writing/idempotently updating the iOS entitlements, `Info.plist`, and
  `project.pbxproj` patches.

### `sync_package_examples.dart`

**Overview:** Copies whatever `git` tracks (or would track, respecting each source's own
`.gitignore`, via `git ls-files --others --exclude-standard --cached`) out of
`example/backend` and `example/app` into `zenpay_dart/example/`,
`zenpay_flutter/example/backend/`, and `zenpay_flutter/example/app/`. Exists because
`dart pub publish` bundles each package's own `example/` for its pub.dev score, and a
monorepo-root `example/` sibling directory is never included in an individual package's
publish archive. `example/backend` and `example/app` are the single source of truth —
never hand-edit any of the three destinations; they're fully replaced on every run. Run
manually with `dart run cli.dart --sync-examples`, or automatically before every
`--release:dart:*`/`--release:flutter:*`.

- **`_excludedBasenames`**: Basenames skipped regardless of directory (`CLAUDE.md`,
  `AGENTS.md`), matching the existing `zenpay_dart/.pubignore` convention; `AGENTS.md` is
  also always a symlink `File.copySync` cannot resolve as a native Windows path.
- **`_SyncTarget`**: Record typedef for one copy operation — `source`/`destination`
  relative to the repo root, plus `localOverrides` mapping a package name to its path
  relative to `destination`.
- **`_targets`**: The three configured copies (`example/backend` into `zenpay_dart/example`
  and `zenpay_flutter/example/backend`; `example/app` into `zenpay_flutter/example/app`),
  each with the `dependency_overrides` needed to resolve against the in-repo package.
- **`buildParser()`**: Builds the `--root` parser; a top-level function so tests can
  exercise parsing without invoking `main` (which calls `exit`).
- **`main(List<String> arguments)`**: CLI entrypoint — runs `syncExample` for every entry
  in `_targets` and prints a summary line per copy.
- **`syncExample(String root, String source, String destination, {Map<String, String> localOverrides})`**:
  Performs one copy — clears the destination (removing a stale symlink or directory),
  copies every `git ls-files`-tracked file from `source`, then applies
  `_stripWorkspaceResolution`, `_writeDependencyOverrides`, and
  `_fixAnalysisOptionsInclude`. Public so tests can call it directly against a temp
  directory.
- **`_stripWorkspaceResolution(String destPath)`**: Removes the copied `pubspec.yaml`'s
  `resolution: workspace` line — left in place it breaks `dart pub get` for the entire
  monorepo, since the destination isn't itself a declared workspace member.
- **`_writeDependencyOverrides(String destPath, Map<String, String> localOverrides)`**:
  Writes a generated `pubspec_overrides.yaml` pointing each copy's SDK dependency at the
  in-repo package path, since the committed version constraint (e.g. `zenpay_dart: ^0.1.0`)
  can't resolve before that package's first real pub.dev publish.
- **`_fixAnalysisOptionsInclude(String destPath)`**: Repoints the copied
  `analysis_options.yaml`'s `include:` from the monorepo root's file (unreachable
  standalone) to `package:lints/recommended.yaml`, a dependency every copy's own
  `pubspec.yaml` actually declares.

### `check_claude_md.dart`

**Overview:** Checks every git-tracked `CLAUDE.md` (or one given path) against
`scripts/claude_md_template.md`, the single source of truth for what a `CLAUDE.md` must
contain — required `## ` section headings in order, plus per-file coverage: every file
matched by a template `coverage:` glob must appear as a dedicated heading or bullet entry,
not just a prose mention. Run via
`dart run scripts/check_claude_md.dart [path/to/CLAUDE.md]`.

- **`ClmTemplate`**: The parsed contract from `claude_md_template.md` —
  `requiredSections` (ordered `## ` heading names) and `coverageGlobs` (file globs relative
  to each CLAUDE.md's own directory).
- **`parseTemplate(String text)`**: Parses the template file's contents into a
  `ClmTemplate` — every `## ` heading becomes a required section, every `coverage: <glob>`
  line a coverage glob; everything else is documentation and ignored.
- **`checkClaudeMd({required String docText, required String sourceDir, required ClmTemplate template})`**:
  Checks one CLAUDE.md's text against `template` — verifies the top-level `# ` title,
  required-section presence and order, and expands each coverage glob under `sourceDir` to
  confirm every matched file has a dedicated entry. Returns one human-readable violation
  per problem, empty when the document conforms; pure aside from the glob filesystem
  reads, so tests can drive it with temp-directory fixtures.
- **`_hasEntry(String path, List<String> lines)`**: True when `path` has a dedicated entry
  — a `### `/`## ` heading or `- `/`* ` bullet line containing the path anywhere in it; a
  mid-prose mention doesn't count.
- **`_expandGlob(String glob, String sourceDir)`**: Expands a template `coverage:` pattern
  under `sourceDir` into absolute forward-slashed file paths; supports `*.ext` (top level
  only) and `dir/**/*.ext` (recursive), the only shapes the template uses.
- **`_forward(String path)`**: Normalizes Windows path separators so relative-path string
  math elsewhere never mixes `\` and `/`.
- **`_trackedClaudeMds(String root)`**: Every `CLAUDE.md` git knows about under `root` —
  tracked plus untracked-but-not-ignored — so the generated `zenpay_*/example/` copies
  (gitignored) are never checked.
- **`_usage()`**: Returns the CLI's usage/help text.
- **`main(List<String> arguments)`**: CLI entrypoint — resolves the template next to this
  script, checks each given (or every tracked) CLAUDE.md, prints a `PASS`/`FAIL` line per
  document plus its violations, and exits `1` if any failed.

### `check_claude_md_test.dart`

**Overview:** Fixture-based tests for `check_claude_md.dart`, in the same temp-directory
style as `apply_platform_config_test.dart`: each case builds a throwaway document and,
where coverage is involved, the matching source tree on disk, then asserts the exact
violations reported.

- **`main()`**: Test suite entrypoint; groups cover `parseTemplate` extraction, section
  presence/order/CRLF handling, and coverage matching — dedicated entries via
  heading/bullet/link styles, prose-only mentions being rejected, and the top-level glob
  not reaching into subdirectories.

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
