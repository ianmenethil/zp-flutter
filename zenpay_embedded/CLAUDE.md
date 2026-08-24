# zenpay_embedded — Optional In-App WebView Presenter

Optional in-app WebView presentation for ZenPay Hosted Checkout, via `webview_flutter`. Not
a default presentation — `zenpay_flutter`'s Android Custom Tabs / iOS
`SFSafariViewController` presenter is the default and the recommended choice; this package
exists for merchants who explicitly need inline/modal checkout instead.

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[zenpay_flutter](../zenpay_flutter/CLAUDE.md)** — The SDK this package depends on: `CheckoutPresenter` (the contract implemented here) and `ZpReturnUriSource`.
- **[README.md](README.md)** — Usage and the WebView/PCI policy this package enforces.

## Non-negotiable rules

1. **Never call `addJavaScriptChannel` or `setOnConsoleMessage` anywhere in `lib/`.** Barred
   by the `no-js-bridge` `lefthook` pre-commit gate (root `lefthook.yml`), not by convention.
   On iOS, `webview_flutter` registers the message handler at the `WKWebViewConfiguration`
   level regardless of any frame-scoping flag — there is no supported way to make a channel
   safe, only to not add one. See `README.md` § WebView policy for the full reasoning.
2. **Never accept a caller-supplied `WebViewController`.** `ZenPayCheckoutWebView` builds its
   own; a supplied controller could carry a channel that the grep gate above cannot see.
3. **Never let the WebView navigate to anything that isn't `https`, and never allowlist
   navigation by host.** 3DS/issuer ACS hosts cannot be enumerated in advance
   (`decide_web_view_navigation.dart`). The host allowlist's job stays where it already is:
   validating the checkout URL before launch, in `zenpay_flutter`.
4. **Never let the WebView load a merchant-authored page.** Its top-level document must
   always be the ZenPay hosted page itself. A merchant page with the checkout embedded as a
   sub-frame alongside merchant script is a different, materially riskier architecture (see
   README's SAQ A vs SAQ A-EP note) and is out of scope for this package.
5. **Never expose `ZenPayCheckoutWebView` from the public barrel (`lib/zenpay_embedded.dart`).**
   `EmbeddedCheckoutPresenter` owns the entire presentation — sheet, sizing, teardown — the
   same way the default Custom Tabs/Safari presenter does. There is no widget for a merchant
   to place in their own tree; adding one back reopens exactly the misuse surface this
   package's redesign closed.
6. **Do not promise SAQ-A eligibility anywhere in this package's docs.** State what the
   package's controls do; eligibility is the merchant's acquirer/QSA's call.

## Source Guide

### `lib/src/decide_web_view_navigation.dart`

**Overview:** Navigation policy for the embedded checkout WebView. Kept out of the widget because a `NavigationDelegate` cannot be driven without a `WebViewPlatform`, and this is the half worth testing on the VM. Not exported from the barrel — internal rule, not API.

- **`blankPage`**: The inert `about:blank` page the widget loads to take the hosted checkout off screen; allowed past the `https`-only rule below rather than blocked by it.
- **`decideNavigation(String url, {required Uri returnUriAddress, required void Function(Uri uri) onReturnUri})`**: Decides whether the embedded WebView may follow `url` — blocks every non-`https` scheme (issuer 3DS ACS hosts can't be enumerated in advance, so this can't be narrowed to a host allowlist), and calls `onReturnUri` then prevents navigation exactly when `url` matches `returnUriAddress`.

### `lib/src/listen_for_return_in_web_view.dart`

**Overview:** Return URI source backed by intercepted WebView navigation, rather than OS-level App Links/Universal Links — a navigation inside an in-process WebView is never handed off to the platform's deep-link resolver, so `zenpay_flutter`'s `AppLinksReturnUriSource` never sees it.

- **`final class WebViewReturnUriSource implements ZpReturnUriSource`**: Feeds return URIs intercepted from `ZenPayCheckoutWebView`'s navigation delegate into a broadcast stream.
- **`WebViewReturnUriSource.uris`**: The stream `ZpCheckout` subscribes to.
- **`WebViewReturnUriSource.addUri(Uri uri)`**: Emits an intercepted return URI; performs no validation of its own — `ZpCheckout` applies its own authoritative `ZpReturnValidator` to everything received here.
- **`WebViewReturnUriSource.dispose()`**: Closes the underlying stream controller.

### `lib/src/render_checkout_web_view.dart`

**Overview:** Renders one ZenPay Hosted Checkout session inside an in-app WebView. Always constructed by `EmbeddedCheckoutPresenter` as the content of a modal bottom sheet it presents itself — never instantiated or placed in a merchant's own widget tree, and deliberately accepts no caller-supplied `WebViewController` (a supplied controller could carry a JS channel the `no-js-bridge` grep gate can't see).

- **`abstract interface class EmbeddedStateInterface`**: State-attachment interface between `ZenPayCheckoutWebView` and `EmbeddedCheckoutPresenter` (`loadUrl`, `clear`); internal, not exported.
- **`final class ZenPayCheckoutWebView extends StatefulWidget`**: The `webview_flutter` widget itself — wires `decideNavigation` into its `NavigationDelegate`, enables the Android Payment Request API for Google Pay, and shows a fixed load-failure message on `onWebResourceError` (the platform's own error description is discarded since it can embed the checkout URL's secure token).
- **`_ZenPayCheckoutWebViewState.clear()`**: Takes the hosted checkout off screen and discards its browsing state (cache, local storage, cookies) — app-wide, since `webview_flutter` exposes no per-instance browsing-data store on either platform.

### `lib/src/open_checkout_in_web_view.dart`

**Overview:** Presenter implementation backing the embedded in-app WebView mode. Presents ZenPay Hosted Checkout in a modal bottom sheet it shows and dismisses itself — owns the entire presentation surface the same way `zenpay_flutter`'s Custom Tabs/`SFSafariViewController` presenter owns its surface. Requires the `GlobalKey<NavigatorState>` already attached to the host app's `MaterialApp`, since `ZpCheckout.open` calls `openCheckout` without a `BuildContext` of its own.

- **`final class EmbeddedCheckoutPresenter extends CheckoutPresenter`**: The presenter itself; owns a `WebViewReturnUriSource` that must be passed as the owning `ZpCheckout`'s `returnUriSource`.
- **`EmbeddedCheckoutPresenter.openCheckout(Uri url, {required bool showTitle, required bool allowExternalBrowserFallback})`**: Presents `url` in a modal bottom sheet hosting the embedded WebView. `showTitle`/`allowExternalBrowserFallback` have no equivalent in this presentation mode and are accepted only to satisfy the `CheckoutPresenter` contract.
- **`EmbeddedCheckoutPresenter.dismissCheckout()`**: Pops the sheet if one is open.
- **`EmbeddedCheckoutPresenter.dispose()`**: Closes this presenter's event stream and its `returnUriSource`; call once, when the owning `ZpCheckout` is disposed.

### `lib/zenpay_embedded.dart`

**Overview:** The root library barrel file. An explicit opt-in with its own `webview_flutter` dependency footprint — merchants who never import it never resolve that dependency at all.

- **`zenpay_embedded.dart` (Barrel Export)**: Exports only `open_checkout_in_web_view.dart` (`EmbeddedCheckoutPresenter`). `ZenPayCheckoutWebView`, `decideNavigation`, and `WebViewReturnUriSource` all stay internal — see rule 5 below.

## Verification

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```

Confirm the bridge gate actually fires: temporarily add an `addJavaScriptChannel` call under
`lib/`, then run `grep -rnE "addJavaScriptChannel|setOnConsoleMessage" zenpay_embedded/lib`
(the same check `lefthook.yml`'s `no-js-bridge` command runs) and confirm it's found, then
remove it.
