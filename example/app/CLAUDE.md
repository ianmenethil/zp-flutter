# example/app — Reference Flutter Client

Reference Flutter client for the combined ZenPay example: fetches a checkout session from `example/backend`, presents ZenPay Hosted Checkout via `zenpay_flutter`, and handles the return. It is a *reference implementation*, not a library — merchants copy the pattern, not the package.

---

## Related Guides

- **[Combined Example](../CLAUDE.md)** — Two-app architecture, how this app and `example/backend` fit together.
- **[zenpay_flutter](../../zenpay_flutter/CLAUDE.md)** — The SDK this app depends on (`../../zenpay_flutter` via Melos `path:`) for checkout presentation and return handling.
- **[example/backend](../backend/CLAUDE.md)** — The server this app fetches sessions from.

---

## Source Guide

Overview of every source file in `lib/`, detailing each file's purpose along with a concise breakdown of its notable classes, functions, and widgets.

### `lib/core/config/app_config.dart`

**Overview:** Demo configuration loaded via `--dart-define-from-file=.env` (see `.env.example`); backend base URL, checkout return URI, allowed checkout hosts, and reCAPTCHA site key, all defaulting to values that run the demo unconfigured against a local backend.

- **`recaptchaSiteKey`**: reCAPTCHA Enterprise site key, web only — empty (and reCAPTCHA disabled entirely) on every other platform.
- **`recaptchaClient`**: the `AppRecaptchaClient` set once `main()`'s `fetchAppRecaptchaClient` call resolves; stays `null` when `recaptchaSiteKey` is empty.
- **`backendBaseUrl`**: the example backend's base URL, read from the `BACKEND_BASE_URL` dart-define.
- **`appReturnUri`**: the checkout return URI the SDK expects; platform-dependent (web origin vs. mobile App Link), read from `APP_RETURN_URI_WEB`/`APP_RETURN_URI_MOBILE`.
- **`allowedCheckoutHosts`**: the checkout host allowlist, read from the `ALLOWED_CHECKOUT_HOSTS` dart-define.

### `lib/core/recaptcha/app_recaptcha_client.dart`

**Overview:** Defines the reCAPTCHA Enterprise client contract for this demo (web only). The concrete implementation is `app_recaptcha_client_web.dart`, resolved via `app_recaptcha_client_factory.dart`'s conditional import.

- **`abstract class AppRecaptchaClient`**: contract for a reCAPTCHA Enterprise client capable of minting an assessment token; `execute(String action)` is its sole method.

### `lib/core/recaptcha/app_recaptcha_client_factory.dart`

**Overview:** Platform resolver for `AppRecaptchaClient` — conditionally imports the web implementation (`dart.library.js_interop`) or the unreachable non-web stub.

- **`fetchAppRecaptchaClient(String siteKey)`**: fetches a platform-specific `AppRecaptchaClient` for `siteKey` by delegating to whichever implementation the conditional import resolved.

### `lib/core/recaptcha/app_recaptcha_client_unsupported.dart`

**Overview:** Non-web `AppRecaptchaClient` resolution target. reCAPTCHA is web-only in this demo, so this file exists only because Dart's conditional import needs a compilable target for every platform — unreachable at runtime.

- **`fetchAppRecaptchaClient(String siteKey)`**: always throws `UnsupportedError` — reCAPTCHA has no implementation outside web.

### `lib/core/recaptcha/app_recaptcha_client_web.dart`

**Overview:** Web `AppRecaptchaClient`: loads Google's `enterprise.js` directly and calls `grecaptcha.enterprise.execute` via `dart:js_interop` — the same low-level interop style as `zenpay_flutter`'s `checkout_presenter_web.dart` (raw `@JS()` externals, no `package:web` dependency).

- **`fetchAppRecaptchaClient(String siteKey)`**: loads the enterprise script for `siteKey`, waits for `grecaptcha.enterprise` readiness, and returns a `_WebAppRecaptchaClient`.
- **`_WebAppRecaptchaClient`**: private `AppRecaptchaClient` implementation whose `execute` calls the JS-interop `grecaptcha.enterprise.execute` and unwraps the resulting JS promise/string.
- **`_loadEnterpriseScript(String siteKey)`**: loads `enterprise.js?render=<siteKey>` into `<head>` once per site key, reusing the same in-flight/completed load on repeat calls.
- **`_whenReady()`**: resolves once `grecaptcha.enterprise` finishes its own internal setup, per Google's documented readiness callback.
- **`_documentHead`/`_createElement`/`_Element`/`_ScriptElement`/`_grecaptchaEnterpriseReady`/`_grecaptchaEnterpriseExecute`/`_ExecuteOptions`**: raw `@JS()` externals binding DOM script injection and the `grecaptcha.enterprise` API.

### `lib/core/theme/theme.dart`

**Overview:** Zenith brand `ThemeData` for the sample app — light/dark colour schemes, typography, and component themes (buttons, inputs, app bar) built from Zenith design tokens; SDK widgets inherit the ambient `Theme`.

- **`ZenithTheme`**: factory namespace for light/dark themes.
- **`ZenithTheme.light()`**: builds the light `ThemeData` from the Zenith `ColorScheme.light` tokens.
- **`ZenithTheme.dark()`**: builds the dark `ThemeData` from the Zenith `ColorScheme.dark` tokens.
- **`ZenithTheme._theme({required Brightness brightness, required ColorScheme colorScheme})`**: shared private builder applying typography and card/button/input/app-bar themes; `light`/`dark` differ only in the `colorScheme` passed in.

### `lib/embedded_demo_main.dart`

**Overview:** Standalone demo entry point for `zenpay_embedded`'s in-app WebView checkout presentation. A separate entry point rather than a mode inside `lib/main.dart`, so this demo never touches that file; renders the exact same `CheckoutPage` as the real app with only the presenter swapped. Run via `dart run cli.dart --android-webview`.

- **`main()`**: initializes Flutter bindings, optionally initializes reCAPTCHA Enterprise, and runs `_EmbeddedDemoApp`.
- **`_EmbeddedDemoApp`**: private `StatelessWidget` app shell wiring the shared `_navigatorKey` and `_presenter` into `CheckoutPage`.
- **`_presenter`**: the single `EmbeddedCheckoutPresenter` constructed once outside the widget tree, since `CheckoutPage` reads it only in `initState` — rebuilding it per-`build()` would leak every presenter after the first.
- **`_navigatorKey`**: the `GlobalKey<NavigatorState>` shared between `MaterialApp` and `_presenter`.

### `lib/features/checkout/models/checkout_modes.dart`

**Overview:** Checkout mode selectors for the sample UI — the ZenPay `/v2/sessions` `mode` value (0–3) plus its UI label, subtitle, and icon. There is no presentation-mode selector: the SDK only ever presents checkout in a system browser surface.

- **`enum TransactionMode`**: `makePayment`, `tokenise`, `customPayment`, `preauthorization` — each carries its ZenPay wire `mode` value plus `label`/`subtitle`/`icon` for the picker cards.
- **`TransactionMode.usesAmount`**: whether this mode takes an amount at all (every mode but `tokenise`).
- **`TransactionMode.amountPresets`**: whole-dollar quick-pick presets shown below the amount field; a UI convenience only, the backend accepts any positive amount.

### `lib/features/checkout/models/mock_customer.dart`

**Overview:** Demo placeholder generators for the sample form — a fresh random customer identity and amount used whenever a field is left blank.

- **`randomCustomer()`**: returns a placeholder `(name, email, reference, phone)` record drawn from a fixed character name pool.
- **`randomAmount()`**: returns a placeholder amount between $1.00 and $500.00.

### `lib/features/checkout/services/checkout_service.dart`

**Overview:** HTTP client for the two-step checkout flow `example/backend` exposes — prepare a signed checkout token, exchange it for a checkout URL, and poll session status.

- **`BackendError`**: exception carrying the backend's HTTP status code and machine-readable error `code`; thrown by `_body` when the response status doesn't match what's expected.
- **`ExchangeResponse`**: response model for `POST /api/v1/checkout/exchange`, holding the launch `checkoutUrl`.
- **`StatusResponse`**: response model for `GET /api/v1/sessions` — the backend's authoritative status, `callbackVerified` flag, verified mode-specific references, and the raw `callbackPayload`.
- **`prepareCheckout(Uri baseUrl, Map<String, Object?> fields, {http.Client? client, String? recaptchaToken})`**: step 1 — posts order/customer `fields` (plus idempotency key, reCAPTCHA, and client-type headers) and returns a signed checkout token.
- **`exchangeCheckout(Uri baseUrl, String checkoutToken, {http.Client? client})`**: step 2 — exchanges `checkoutToken` (as a bearer token) for an `ExchangeResponse`; safe to call more than once, always resolves to the same attempt.
- **`fetchStatus(Uri baseUrl, String token, {http.Client? client})`**: fetches the backend's authoritative `StatusResponse` for the return `token` (`t`) query value.

### `lib/features/checkout/ui/checkout_page.dart`

**Overview:** The demo's checkout screen end to end — creates a session against `example/backend`, presents hosted checkout via `zenpay_flutter`, waits for the return, then confirms the authoritative result against the backend. `_pay`'s ordering is load-bearing: `reserveLaunch()` must run synchronously before the first `await`, since a browser only honours `window.open` inside an unbroken user gesture.

- **`CheckoutPage`**: `StatefulWidget` home screen — transaction-mode picker, customer fields, pay button, and a results slot; accepts optional `presenter`/`returnUriSource` overrides (used by `embedded_demo_main.dart`'s WebView demo).
- **`_CheckoutPageState`**: owns all form/selection state and the `ZpCheckout` instance; holds no HTTP or SDK state elsewhere.
- **`_CheckoutPageState._pay()`**: reserves the launch, resolves an optional reCAPTCHA token, calls `prepareCheckout`/`exchangeCheckout`, and opens checkout via `ZpCheckout.open`.
- **`_CheckoutPageState._resolve(ZpCheckoutOutcome outcome)`**: maps a `ZpCheckoutOutcome` to a displayed result, confirming any return against the backend's `fetchStatus` before showing success.
- **`_CheckoutPageState._buildTransactionModeSection`/`_buildCustomerFields`/`_buildResults`/`_buildCallbackPayloadPanel`/`_buildAppBar`/`build`**: private widget-building helpers composing the page body.
- **`_describeCheckoutEvent(ZpCheckoutEvent event)`**: readable one-line summary of a `ZpCheckoutEvent`, used by the `ZpCheckoutObserver` debug log.
- **`_validateEmail(String rawValue)`/`_validatePhone(String rawValue)`**: blank-is-fine field validators mirroring the backend's own patterns.

### `lib/features/checkout/ui/widgets/zenpay_amount_field.dart`

**Overview:** Payment amount field with currency affixes and quick-pick presets.

- **`ZenPayAmountField`**: `StatelessWidget` rendering a large `$<amount> AUD`-styled numeric field plus preset amount chips that set `controller.text` on tap.

### `lib/features/checkout/ui/widgets/zenpay_environment_banner.dart`

**Overview:** Persistent marker banner for non-production checkout environments — renders an unmissable strip when every allowed checkout host looks like sandbox/UAT, otherwise renders nothing.

- **`ZenPayEnvironmentBanner`**: `StatelessWidget` taking `allowedCheckoutHosts`; shows the sandbox warning banner or `SizedBox.shrink()` depending on `_isNonProduction`.

### `lib/features/checkout/ui/widgets/zenpay_labeled_field.dart`

**Overview:** Labeled outlined text field — style only; validation is the caller's job, surfaced here purely as `errorText`.

- **`ZenPayLabeledField`**: `StatelessWidget` wrapping `TextField` with an always-floating label, optional hint text, keyboard type, error text, and `onChanged`.

### `lib/features/checkout/ui/widgets/zenpay_pay_button.dart`

**Overview:** Pure presentational pay button with a busy/idle label swap — no checkout logic of its own; launch orchestration lives in `checkout_page.dart`'s `_pay`.

- **`ZenPayPayButton`**: `StatelessWidget` rendering a `FilledButton` with a `Semantics`-announced busy/idle state and an `AnimatedSwitcher` label transition between `label` and `busyLabel`.

### `lib/features/checkout/ui/widgets/zenpay_selectable_card.dart`

**Overview:** Selectable bordered option card — the visual template behind the transaction-mode picker (`TransactionMode`, `checkout_modes.dart`).

- **`ZenPaySelectableCard`**: `StatelessWidget` rendering a bordered, tappable card with an icon/label row and subtitle beneath, highlighting its border when `selected`.

### `lib/main.dart`

**Overview:** Entry point for the combined ZenPay example app — handles the web checkout-return popup short-circuit, initializes reCAPTCHA, and launches `ZenPayExampleApp`.

- **`main()`**: initializes Flutter bindings, returns early when this window is a web checkout-return popup (`completeWebCheckoutReturnIfPopup`), otherwise initializes reCAPTCHA and runs `ZenPayExampleApp`.
- **`ZenPayExampleApp`**: app shell `StatelessWidget` applying `ZenithTheme` and opening on `CheckoutPage`.

### `lib/previews/checkout_widgets_previews.dart`

**Overview:** Isolated widget previews for the checkout UI widgets, consumed only by the Flutter Widget Previewer (`flutter widget-preview start`) — the app itself never calls these functions.

- **`zenpayAmountFieldPreview()`**: preview of `ZenPayAmountField` with AUD presets.
- **`zenpaySelectableCardSelectedPreview()`/`zenpaySelectableCardUnselectedPreview()`**: selected/unselected `ZenPaySelectableCard` previews.
- **`zenpayLabeledFieldPreview()`**: preview of `ZenPayLabeledField` with a placeholder hint.
- **`zenpayPayButtonIdlePreview()`/`zenpayPayButtonBusyPreview()`**: idle/busy `ZenPayPayButton` previews.
- **`zenpayEnvironmentBannerPreview()`**: preview of `ZenPayEnvironmentBanner` with sandbox hosts.

---

## 1. Scope & Responsibilities

- `lib/features/checkout/services/checkout_service.dart` talks only to `example/backend`'s two-step checkout flow (`POST /api/v1/checkout/token` to prepare, `POST /api/v1/checkout/exchange` for the checkout URL) plus `GET /api/v1/sessions` for status, all over `http`. It never builds a checkout URL, never touches ZenPay credentials, and never calls ZenPay directly — see `zenpay_flutter`'s own scope rule for why: URL construction and payment confirmation are the backend's job.
- `lib/features/checkout/ui/checkout_page.dart` and its widgets are demonstration UI only — presentation choices here (colors, layout, copy) are not SDK requirements. Do not invent or extend the UI/visual design beyond what the project owner has specified; see [example/CLAUDE.md § Look and Feel](../CLAUDE.md).
- `lib/features/checkout/models/checkout_modes.dart` and `mock_customer.dart` model the demo's own request shapes; they are not part of any SDK's public API surface.
- `lib/previews/checkout_widgets_previews.dart` uses Flutter's widget preview system — keep it in sync when adding new checkout widgets.
- Treat any `ZpCheckoutOutcome` returned by `zenpay_flutter` as provisional. This app must always confirm final status against `example/backend`'s session-status endpoint before showing a success state.

## 2. Flutter Strictness & Code Quality

Adhere to [analysis_options.yaml](analysis_options.yaml): strict casts/inference/raw-types, `const` widgets wherever possible, comprehensive doc comments on any exported symbol.

## 3. Verification Commands

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```

To run the app itself, use `dart run cli.dart --android` / `--ios` / `--web` from the repo root — `example/backend` must already be running (`dart run cli.dart --server`).
