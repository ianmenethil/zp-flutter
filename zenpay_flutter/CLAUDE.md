# ZenPay Flutter SDK Agent Guidelines

Guidelines and standards for working within `zenpay_flutter` (the Flutter client SDK). This package is responsible for presenting the ZenPay Hosted Checkout UI and handling deep-link returns.

---

# ZenPay Flutter SDK — Library Architecture

Overview of all files and folders in `lib/`, explaining their specific purpose and contents:

- **[lib](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib)**: Root library directory containing public barrel exports and internal implementation modules.
- **[lib\src](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src)**: Private implementation root isolating internal logic, platform adapters, and validators.
- **[lib\src\checkout](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/checkout)**: Orchestration layer coordinating checkout session execution, browser presentation, and lifecycle state.
- **[lib\src\checkout\active_checkout.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/checkout/active_checkout.dart)**: Internal `ActiveCheckout` tracking one in-flight checkout launch — the pending outcome, elapsed time, timeout timer, and watched subscriptions — and settling it exactly once.
- **[lib\src\checkout\checkout_controller.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/checkout/checkout_controller.dart)**: Implements `ZpCheckout`, the primary controller managing launch flows, race timeouts, return interception, and disposal.
- **[lib\src\checkout\launch_validator.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/checkout/launch_validator.dart)**: Validates target checkout URLs against allowed hosts before launch. Must not add `merchantUniquePaymentId`-specific rules.
- **[lib\src\configuration](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/configuration)**: Configuration definitions and policy enforcement.
- **[lib\src\configuration\checkout_configuration.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/configuration/checkout_configuration.dart)**: Defines immutable `ZpCheckoutConfiguration` holding host allowlists, expected return URIs, timeouts, and telemetry sinks.
- **[lib\src\exceptions](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/exceptions)**: Strongly-typed exception definitions for error handling.
- **[lib\src\exceptions\checkout_event.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/exceptions/checkout_event.dart)**: Contains `ZpCheckoutException` types for concurrent session collisions, disposal violations, and invalid launch inputs.
- **[lib\src\models](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/models)**: Data models and result types produced during checkout execution.
- **[lib\src\models\checkout_outcome.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/models/checkout_outcome.dart)**: Defines the sealed `ZpCheckoutOutcome` hierarchy (`returnReceived`, `presentationDismissed`, `timedOut`, `launchFailed`).
- **[lib\src\observability](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/observability)**: Structured telemetry and audit event definitions.
- **[lib\src\observability\checkout_event.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/observability/checkout_event.dart)**: Defines sealed `ZpCheckoutEvent` types and `ZpCheckoutObserver` for structured telemetry.
- **[lib\src\presentation](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/presentation)**: Platform-specific browser presentation surfaces and abstractions.
- **[lib\src\presentation\checkout_presenter_mobile.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/presentation/checkout_presenter_mobile.dart)**: Mobile presenter opening Android Custom Tabs and iOS `SFSafariViewController` via `url_launcher`.
- **[lib\src\presentation\checkout_presenter_web.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/presentation/checkout_presenter_web.dart)**: Web presenter implementing synchronous window reservation and new tab navigation via JS interop.
- **[lib\src\presentation\presenter_factory.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/presentation/presenter_factory.dart)**: Conditional-import factory resolving the appropriate `CheckoutPresenter` implementation for Web or Mobile.
- **[lib\src\presentation\presenter.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/presentation/presenter.dart)**: Abstract `CheckoutPresenter` contract defining methods to open, reserve, and dismiss browser surfaces.
- **[lib\src\return_handling](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling)**: Deep link ingestion and return sanitization logic.
- **[lib\src\return_handling\return_uri_source.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/return_uri_source.dart)**: Abstract `ZpReturnUriSource` interface delivering a stream of incoming application deep links.
- **[lib\src\return_handling\return_uri_source_factory.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/return_uri_source_factory.dart)**: Conditional-import resolver picking `AppLinksReturnUriSource` (Mobile) or `WebPopupReturnUriSource` (Web) for `createDefaultReturnUriSource()`, mirroring `presenter_factory.dart`.
- **[lib\src\return_handling\return_validator.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/return_validator.dart)**: Sanitizes and verifies candidate return URIs against host matching and the configured return address. Must not match or reject on `merchantUniquePaymentId`.
- **[lib\src\return_handling\mobile\app_links_return_uri_source.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/mobile/app_links_return_uri_source.dart)**: Ingests App Links and Universal Links on mobile devices using `package:app_links`; also the Mobile branch of `createDefaultReturnUriSource()`.
- **[lib\src\return_handling\web\web_return_message.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_return_message.dart)**: Pure-Dart `postMessage` string protocol (encode/decode) shared by the Web popup sender and receiver below.
- **[lib\src\return_handling\web\web_return_validation.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_return_validation.dart)**: Pure validation logic for the Web return-popup handoff protocol, kept free of `dart:js_interop` so it can be unit tested.
- **[lib\src\return_handling\web\web_popup_return_uri_source.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_popup_return_uri_source.dart)**: Web `ZpReturnUriSource` — listens for the `postMessage` handoff from a same-origin checkout return popup, since `package:app_links` cannot observe navigation in the separate tab `checkout_presenter_web.dart` opens.
- **[lib\src\return_handling\web\web_checkout_return_popup.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_checkout_return_popup.dart)**: Web sender half of the popup handoff — `completeWebCheckoutReturnIfPopup`, called from `main()`, relays the return to `window.opener` via `postMessage` and closes the popup.
- **[lib\src\return_handling\web\web_checkout_return_popup_mobile.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_checkout_return_popup_mobile.dart)**: Mobile no-op stand-in for the popup handoff — the concept doesn't apply off Web.
- **[lib\src\return_handling\web\web_checkout_return_popup_factory.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/src/return_handling/web/web_checkout_return_popup_factory.dart)**: Conditional-import resolver exposing `completeWebCheckoutReturnIfPopup()`, mirroring `presenter_factory.dart`.
- **[lib\testing.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/testing.dart)**: Test utilities barrel exporting `FakeReturnUriSource` for deterministic automated testing.
- **[lib\zenpay_checkout.dart](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/zenpay_checkout.dart)**: Main public barrel export exposing controllers, configurations, outcomes, events, and validation helpers.

## 🔗 Related Guides

- **[Monorepo Root](file:///G:/_zp-repos/zp-flutter-sdk/CLAUDE.md)** — General Melos and workspace guidelines.
- **[Pure Dart SDK](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/CLAUDE.md)** — Server-side cryptography, models, and token validation.
- **[Integration Examples](file:///G:/_zp-repos/zp-flutter-sdk/example/CLAUDE.md)** — Reference merchant backend and app that consume this package.
- **[README.md](README.md)** — Package overview, usage, and API.

`AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

---

## 1. Scope & Security Responsibilities

1. **No Cryptography or Secrets**:
   - This package handles ONLY the client-side Flutter code.
   - **Do not put any cryptographic generation, hashing, or server-side logic in this package.** All of that belongs in `zenpay_dart` (which runs on the merchant's secure backend).
   - Never accept secret API keys in the Flutter widgets.
2. **Launch & Return Lifecycle**:
   - The primary responsibility of this package is safely opening the ZenPay Hosted Checkout URL (which was generated by the backend) via `url_launcher`.
   - It must listen for the return and parse the resulting status, passing it back to the developer — via `app_links` on Mobile (App Links / Universal Links), or via a `postMessage` handoff from a same-origin popup on Web, since `app_links` cannot observe navigation in the separate tab Web presents checkout in. See the `return_handling/` entries above.
3. **Provisional Status**:
   - The Flutter package only provides a _provisional_ payment status based on the user's return URL. Remind developers in docs that final confirmation must happen via backend webhooks (`zenpay_dart`).
4. **No Special-Casing `merchantUniquePaymentId`**:
   - It is an ordinary opaque field, not a correlation key. Do not add a required field for it on any public sealed hierarchy, a dedicated validator, or return-matching/rejection logic.

---

## 2. Flutter Strictness & Code Quality

Adhere strictly to [analysis_options.yaml](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/analysis_options.yaml):

1. **Strict Type Safety**:
   - `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`.
2. **Public API Documentation**:
   - Every exported class, widget, method, and enum in `lib/` must have a comprehensive doc comment explaining its usage. UI components must describe their visual behavior and platform-specific constraints.
3. **Immutability**:
   - Flutter widgets should be `const` wherever possible to optimize the render tree.
   - Models should be immutable, overriding `==` and `hashCode`.

---

## 3. Verification Commands

This package is part of a Melos monorepo. Before completing any change, ensure all checks pass by running the following from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run lint
melos run test
```
