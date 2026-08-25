# zenpay_flutter — Flutter Client SDK

Client-side Flutter SDK for ZenPay Hosted Checkout: presents a checkout URL in a
platform-native browser surface (Android Custom Tabs, iOS `SFSafariViewController`, or a
new web tab), tracks the session lifecycle, intercepts the return, and settles with one
typed outcome. No cryptography, no credentials, no proof of payment — that's `zenpay_dart`,
server-side; a return here is always provisional until confirmed via ZenPay's signed
webhook callback.

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[zenpay_dart](../zenpay_dart/CLAUDE.md)** — Server-side SDK this package pairs with.
- **[zenpay_embedded](../zenpay_embedded/CLAUDE.md)** — Optional in-app WebView presenter implementing this package's `CheckoutPresenter`.
- **[PCI_SAQ_A.md](../PCI_SAQ_A.md)** — Why this package's default presentation is the safer architectural choice.
- **[README.md](README.md)** — Usage.

## Source Guide

### Public entrypoints

- **[zenpay_checkout.dart](lib/zenpay_checkout.dart)** — Barrel export: `ZpCheckout`, `ZpCheckoutConfiguration`, `ZpCheckoutOutcome`, exceptions, `ZpCheckoutEvent`/`ZpCheckoutObserver`, `isAllowedCheckoutUrl`, `CheckoutPresenter`, `ZpReturnUriSource`.
- **[testing.dart](lib/testing.dart)** — `FakeReturnUriSource`, for tests that don't want a real platform channel.

### `lib/src/checkout/`

- **[run_checkout_flow.dart](lib/src/checkout/run_checkout_flow.dart)** — `ZpCheckout`, the main controller: one session at a time, launch validation, presenter invocation, timeout race, return interception, observer telemetry.
- **[track_active_checkout.dart](lib/src/checkout/track_active_checkout.dart)** — Internal bookkeeping for one in-flight launch so an outcome settles exactly once.
- **[validate_checkout_url.dart](lib/src/checkout/validate_checkout_url.dart)** — `isAllowedCheckoutUrl`: HTTPS/port/length/host-allowlist checks before a browser opens.

### `lib/src/configuration/`

- **[checkout_settings.dart](lib/src/configuration/checkout_settings.dart)** — `ZpCheckoutConfiguration`: allowlisted hosts, expected return URI, timeout, browser UI options, length bounds, optional observer. Immutable, validated at construction — see dartdoc/source for current defaults rather than this file.

### `lib/src/exceptions/`

- **[checkout_errors.dart](lib/src/exceptions/checkout_errors.dart)** — Sealed `ZpCheckoutException` hierarchy: already-active, disposed, invalid-launch.

### `lib/src/models/`

- **[checkout_results.dart](lib/src/models/checkout_results.dart)** — Sealed `ZpCheckoutOutcome` hierarchy: return received, presentation dismissed, timed out, launch failed.

### `lib/src/observability/`

- **[checkout_telemetry.dart](lib/src/observability/checkout_telemetry.dart)** — Sealed `ZpCheckoutEvent` hierarchy and the `ZpCheckoutObserver` interface. No logging by default; an observer's own exceptions never affect the checkout.

### `lib/src/presentation/`

- **[open_checkout_contract.dart](lib/src/presentation/open_checkout_contract.dart)** — `CheckoutPresenter`, the contract every presenter (including `zenpay_embedded`'s) implements.
- **[open_checkout_pick_platform.dart](lib/src/presentation/open_checkout_pick_platform.dart)** — Conditional-import factory selecting the platform presenter.
- **[open_checkout_on_mobile.dart](lib/src/presentation/open_checkout_on_mobile.dart)** — Android Custom Tabs / iOS `SFSafariViewController` via `url_launcher`; dismissal is inferred from app-resume plus a grace period.
- **[open_checkout_on_web.dart](lib/src/presentation/open_checkout_on_web.dart)** — Web presenter opening/navigating a second tab; `reserveLaunch()` preserves the user-gesture window across an `await`.

### `lib/src/return_handling/`

- **[listen_for_return_contract.dart](lib/src/return_handling/listen_for_return_contract.dart)** — The `ZpReturnUriSource` interface.
- **[listen_for_return_pick_platform.dart](lib/src/return_handling/listen_for_return_pick_platform.dart)** — Conditional-import default source per platform.
- **[validate_return_url.dart](lib/src/return_handling/validate_return_url.dart)** — `matchesReturnUriAddress`: scheme/host/port/path/length checks on an incoming candidate return URI.
- **[mobile/listen_for_return_on_mobile.dart](lib/src/return_handling/mobile/listen_for_return_on_mobile.dart)** — App Links/Universal Links via `package:app_links`.
- **[web/listen_for_return_on_web.dart](lib/src/return_handling/web/listen_for_return_on_web.dart)** — Same-origin `postMessage` listener for the return popup's handoff.
- **[web/web_popup_sends_url_back.dart](lib/src/return_handling/web/web_popup_sends_url_back.dart)** — `completeWebCheckoutReturnIfPopup()`: called first in `main()` on Web to relay the return and close the popup.
- **[web/web_popup_not_used_on_mobile.dart](lib/src/return_handling/web/web_popup_not_used_on_mobile.dart)** / **[web_popup_pick_platform.dart](lib/src/return_handling/web/web_popup_pick_platform.dart)** — Mobile no-op stub, and the conditional-import resolver, for the above.
- **[web/web_return_protocol.dart](lib/src/return_handling/web/web_return_protocol.dart)** — Pure-Dart `postMessage` payload encode/decode plus origin validation, kept `dart:js_interop`-free so it's unit-testable on the VM.

## Verification

Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test --scope=zenpay_flutter
```
