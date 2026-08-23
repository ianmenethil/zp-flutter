## 0.1.0

- Public `CheckoutPresenter` interface for custom presentation surfaces:
  enables external packages to implement custom browser presentations (e.g.
  embedded WebView) and provide them via the optional `presenter` constructor
  parameter on `ZpCheckout`.
- Initial release of `ZpCheckout`: opens a ZenPay hosted checkout URL in a
  platform-native browser surface and resolves with one sealed
  `ZpCheckoutOutcome` (`ZpReturnReceived`, `ZpPresentationDismissed`,
  `ZpTimedOut`, `ZpLaunchFailed`).
- Mobile presentation via `url_launcher`: Chrome Custom Tabs on Android,
  `SFSafariViewController` on iOS, with optional external-browser fallback
  and resume-based dismissal detection.
- Web presentation via `window.open`, with synchronous popup reservation
  (`reserveLaunch` / `releaseLaunchReservation`) so a launch survives an
  `await` between the tap and opening the checkout URL without being blocked.
- Mobile return handling via `package:app_links` (App Links / Universal
  Links, cold start and runtime).
- Web return handling via a same-origin `postMessage` handoff between a
  checkout return popup and its opener (`completeWebCheckoutReturnIfPopup`,
  `createDefaultReturnUriSource`).
- Strict launch URL validation (`isAllowedCheckoutUrl`): HTTPS only, port
  443, no credentials or fragment, under 4096 characters, host on a
  configurable allowlist.
- Strict return URI validation: exact scheme/host/port/path match against
  the configured return address, length bounds, and rejection of malformed
  or duplicate query parameters.
- `ZpCheckoutConfiguration` for host allowlisting, expected return URI,
  timeout, browser title and external-fallback toggles, and return length
  limits, validated at construction.
- Structured, opt-in telemetry via `ZpCheckoutObserver` and sealed
  `ZpCheckoutEvent`s — the SDK performs no logging or analytics on its own.
- `package:zenpay_flutter/testing.dart` with `FakeReturnUriSource` for
  driving checkout flows deterministically in tests, without platform
  channels or network access.
- Fix for presenter reservation leaks: `ZpCheckout` now calls
  `_presenter.releaseReservation()` on all early-exit paths (disposal,
  concurrent opens, failed security checks) that previously left reservations
  held, preventing lost presentation slots in rapid-retry scenarios. Extracted
  return URI matching as public `matchesReturnUriAddress` for shared use across
  mobile and web return validation; web popup return validation now delegates to
  this shared predicate to eliminate a duplicated same-origin check.
