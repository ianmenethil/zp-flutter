# Coverage Backlog

Gaps and tooling defects found while reviewing test-coverage output on 2026-08-19. All four
items below were fixed and verified on 2026-08-20 (`melos run format/analyze/lint/test` all
pass: zenpay_dart 59, zenpay_flutter 23, backend 41, app 22).

## Baseline (measured 2026-08-19, before fixes)

| Package | Lines | Coverage | Collector |
|---|---|---|---|
| `zenpay_dart` | 383/415 | 92.3% | `coverage:test_with_coverage` |
| `zenpay_flutter` | 138/182 | 75.8% | `flutter test --coverage` |
| `example/app` | 298/370 | 80.5% | `flutter test --coverage` |
| `example/backend` | 404/528 | 76.5% | `coverage:test_with_coverage` |

Stale — re-measure the four `coverage/lcov.info` files if current numbers matter.

### Correctly absent from the reports — do not "fix"

These have no executable lines, so a collector omitting them is right, not a gap:

- `zenpay_dart/lib/zenpay_dart.dart`, `zenpay_flutter/lib/zenpay_checkout.dart` — barrel exports
- `zenpay_dart/lib/src/defaults.dart` — `static const` only
- `zenpay_flutter/lib/src/return_handling/return_uri_source.dart` — abstract interface, no bodies
- `example/app/lib/previews/checkout_widgets_previews.dart` — dev-only previews

---

## 1. Generated coverage artifacts are commit-eligible — DONE

Added `**/coverage/` to `.gitignore`.

## 2. `coverage:dart` emitted machine-absolute paths — DONE

Root `pubspec.yaml`'s `coverage:dart` melos script now chains `coverage:format_coverage`
with `--base-directory .`, pointed at `.dart_tool/package_config.json` via
`$MELOS_ROOT_PATH` (that file only exists at the workspace root under Dart pub workspaces,
not per-package, so a plain relative path fails under `melos exec`). Verified: `SF:` lines
are package-relative (e.g. `SF:lib\src\callback.dart`), not machine-absolute.

## 3. `AppLinksReturnUriSource` had zero coverage — DONE

Added `zenpay_flutter/test/app_links_return_uri_source_test.dart`: initial link is yielded
before the runtime stream, no-initial-link falls through to the stream alone, and an
initial-link lookup failure is swallowed without breaking the stream.

## 4. Web presenter is never instrumented — RESOLVED: gap accepted, documented

`flutter test --platform chrome` does not terminate in this environment (probed
2026-08-20 with a throwaway test: hung past a 120s timeout, logging "Connection closed
before test suite loaded" first). `checkout_presenter_web.dart`, the web branch of
`presenter_factory.dart`, and the no-op default bodies in `presenter.dart` remain untested
by any automated test in this repo — read `zenpay_flutter` coverage percentages as
mobile-path coverage only.
