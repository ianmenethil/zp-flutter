# PACKAGES.md — Third-Party Dependency Inventory

Every direct dependency declared in this repo's `pubspec.yaml` files: what it is, where it's
declared, which version constraint is pinned, who publishes/maintains it, and why this repo
uses it. Distinct from the root [README.md § 📦 Packages](README.md#-packages) section, which
lists *this repo's own* SDK packages (`zenpay_dart`, `zenpay_flutter`, `zenpay_embedded`) —
this file is about everything *those* packages (and the example apps) depend on.

Version constraints below are the `^x.y.z` caret ranges as declared in each `pubspec.yaml` at
the time of writing — the exact resolved version actually installed can be newer within that
range; check `pubspec.lock` for that. Transitive-only dependencies (pulled in by another
package, never declared directly) are not listed here.

Generated dirs are excluded: `zenpay_dart/example/`, `zenpay_flutter/example/`, and
`.widget_preview/` are regenerated copies/tooling scaffolds, not independent dependency sets —
see [scripts/CLAUDE.md](scripts/CLAUDE.md).

---

## This Repo's Own Packages

Not third-party — listed here only as the "where" column's shorthand names used below.

| Package | Path | What it is |
| :--- | :--- | :--- |
| `zenpay_dart` | `zenpay_dart/` | Pure-Dart backend SDK: fingerprints, launch URLs, callback verification, callback URL tokens. |
| `zenpay_flutter` | `zenpay_flutter/` | Flutter client SDK: presents ZenPay Hosted Checkout, handles the return, reports one typed outcome. |
| `zenpay_embedded` | `zenpay_embedded/` | Optional in-app WebView presenter, depends on `zenpay_flutter`. |
| `example/backend` | `example/backend/` | Reference merchant backend (Shelf server). |
| `example/app` | `example/app/` | Reference Flutter client app. |
| root workspace | `pubspec.yaml` (repo root) | Melos workspace root — dev tooling only, no runtime code of its own. |

---

## Dart SDK & Flutter SDK

| Name | Version constraint | Where | Publisher | Why |
| :--- | :--- | :--- | :--- | :--- |
| Dart SDK | `^3.13.0` (every package) | every package | Google — the Dart team | The language/runtime itself. Required for primary-constructor syntax (`class const`, `enum const`), used throughout `zenpay_dart`'s models. |
| Flutter SDK | `>=3.44.0` | `zenpay_flutter`, `zenpay_embedded`, `example/app` | Google — the Flutter team | The UI framework — widgets, `flutter_test`, `integration_test` all ship as part of it, not as separate pub.dev packages. |

---

## Dart Team (`dart.dev` / `tools.dart.dev`)

Official packages maintained by the Dart team.

| Package | Version | Where | Why |
| :--- | :--- | :--- | :--- |
| `args` | `^2.7.0` | root (`cli.dart`) | Parses `cli.dart`'s `--server`/`--android`/`--release:*`/etc. mode flags and options via `ArgParser`. |
| `collection` | `^1.19.0` | `zenpay_flutter` | `SetEquality<String>` for value-equality on `ZpCheckoutConfiguration`'s `allowedCheckoutHosts` set (immutable config classes require `==`/`hashCode`). |
| `coverage` | `^1.15.1` | `zenpay_dart` (dev) | LCOV coverage generation for pure-Dart packages (`melos run coverage:dart`; Flutter packages use `flutter test --coverage` instead). |
| `http` | `^1.6.0` | `example/app` (dep); `example/backend` (dev) | `example/app`'s `checkout_service.dart` calls the backend's `/api/v1/checkout/*` and `/api/v1/sessions` endpoints; `example/backend`'s tests use it as an HTTP client against the running server. |
| `lints` | `^6.1.0` | `zenpay_dart`, `example/backend` (dev) | Base rule set `analysis_options.yaml` extends via `package:lints/recommended.yaml` (plain-Dart packages; Flutter packages use `flutter_lints` instead). |
| `logging` | `^1.3.0` | `example/backend` | Structured logging in the reference backend server. |
| `meta` | `^1.16.0`–`^1.18.0` | `zenpay_flutter`, `zenpay_embedded`, `example/backend` | `@visibleForTesting`, `@internal` annotations (e.g. `resetInitialLinkConsumedForTesting()` in `zenpay_flutter`). |
| `shelf` | `^1.4.2` | `example/backend` | The HTTP server framework the reference backend is built on. |
| `shelf_router` | `^1.1.4` | `example/backend` | Route dispatch on top of `shelf` for the backend's REST endpoints. |
| `shelf_static` | `^1.1.3` | `example/backend` | Serves a `web/` build directory as static files (`createStaticHandler`) when one exists — the Docker/Cloudflare combined-image deployment path. |
| `test` | `^1.31.0` | root, `zenpay_dart`, `example/backend` (dev) | Standard Dart test runner for pure-Dart packages. |

---

## Flutter Team (`flutter.dev`)

Official first-party Flutter plugins and lint config.

| Package | Version | Where | Why |
| :--- | :--- | :--- | :--- |
| `flutter_lints` | `^6.0.0` | `zenpay_flutter`, `zenpay_embedded`, `example/app` (dev) | Flutter's official recommended lint set. |
| `plugin_platform_interface` | `^2.1.8` | `zenpay_flutter` (dev only) | Transitive dependency of `url_launcher`; declared directly only so tests can fake `UrlLauncherPlatform.instance` — never ships to consumers. |
| `url_launcher` | `^6.3.2` | `zenpay_flutter` | Opens Android Custom Tabs / iOS `SFSafariViewController` (mobile) and a new browser tab via `window.open` (web) to present ZenPay Hosted Checkout. |
| `url_launcher_platform_interface` | `^2.3.2` | `zenpay_flutter` (dev only) | Same reason as `plugin_platform_interface` — faking the platform instance in tests. |
| `webview_flutter` | `^4.14.1` | `zenpay_embedded` | The in-app WebView widget `ZenPayCheckoutWebView` renders the hosted checkout page in. |
| `webview_flutter_android` | `^4.13.0` | `zenpay_embedded` | Android-specific `WebViewController` creation params and the Payment Request API toggle needed for Google Pay inside the embedded WebView. |

---

## Google APIs Team (`google.dev`)

| Package | Version | Where | Why |
| :--- | :--- | :--- | :--- |
| `googleapis` | `^16.0.0` | `example/backend` | `package:googleapis/recaptchaenterprise/v1.dart` — the reCAPTCHA Enterprise assessment client used to gate `POST /checkout/token` for web requests. |
| `googleapis_auth` | `^2.0.0` | `example/backend` | `package:googleapis_auth/auth_io.dart` — Google Cloud service-account authentication for the reCAPTCHA Enterprise API calls above. |
| `googleapis_beta` | `^9.0.0` | `example/backend` | **Declared but not imported anywhere in this repo's source** (verified: no `package:googleapis_beta` import in `example/backend/lib` or `test/`) — appears to be an unused leftover dependency. Worth confirming with whoever added it before removing. |

---

## Independent / Community-Maintained

| Package | Version | Where | Publisher (pub.dev) | Why |
| :--- | :--- | :--- | :--- | :--- |
| `app_links` | `^7.2.1` | `zenpay_flutter` | `cow-level.ovh` | Captures Android App Links / iOS Universal Links for mobile checkout-return deep-link handling (`AppLinksReturnUriSource`). |
| `dart_code_linter` | `^4.1.9` | `zenpay_dart`, `zenpay_flutter`, `zenpay_embedded` (dev) | `bancolombia.com` | Unused-code/dead-code detection (`melos run lint` → `dart_code_linter:metrics analyze lib`). Not declared at the workspace root — each package that needs it declares it itself. |
| `dotenv` | `^4.2.0` | `example/backend` | `practicalflutter.com` | Loads `example/backend/.env` into `AppConfig` (API keys, `TOKEN_SECRET`, etc. — see that package's `.env.example`). |
| `hashlib` | `^2.4.2` | `zenpay_dart`, `example/backend` | `bitanon.dev` | SHA3-512 hashing, HMAC-SHA3-512, and secure random bytes — the cryptographic core of fingerprints, callback `ValidationCode` verification, and callback URL tokens. |
| `melos` | `^8.3.0` | root (dev) | `invertase.io` (Invertase) | The monorepo package-management tool itself — drives the Dart pub workspace that links sibling packages via ordinary version constraints (not `path:` deps), runs `melos run <script>` across every package. |
| `very_good_analysis` | `^10.3.0` | root, `zenpay_dart` (dev) | `verygood.ventures` (Very Good Ventures) | Stricter-than-default analysis rules (`strict-casts`, `strict-inference`, `strict-raw-types`) — the basis for this repo's "no `dynamic`" strictness rule. |

---

## Non-Dart Tooling

Not a pub.dev package, but wired into the workspace's own `pubspec.yaml`.

| Tool | Where | Why |
| :--- | :--- | :--- |
| [lefthook](https://github.com/evilmartians/lefthook) | root `pubspec.yaml`'s `scripts.prepare` (`npx --yes lefthook install`) | Installs the git pre-commit hooks (`lefthook.yml`) — the only enforcement gate today, since CI is currently disabled (see [CLAUDE.md](CLAUDE.md)). Installed via `npx` because the pub.dev `lefthook` wrapper package is Dart-2-only. |

---

## Related Guides

- **[Monorepo Root](CLAUDE.md)** — Melos workspace overview.
- **[README.md § 📦 Packages](README.md#-packages)** — this repo's own SDK packages (a different "packages" list than this file).
- **[GETTING_STARTED.md](GETTING_STARTED.md)** — clone/bootstrap/run steps.
