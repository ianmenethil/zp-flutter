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

## Key files

- `lib/src/decide_web_view_navigation.dart` — `decideNavigation`, not exported from the
  barrel (internal only). Restricts navigation to `https` and intercepts the return redirect
  before the WebView can follow it.
- `lib/src/listen_for_return_in_web_view.dart` — `WebViewReturnUriSource implements
  ZpReturnUriSource`. A navigation happening inside an in-process WebView is not handed off
  to the OS App Link/Universal Link resolver the way a system browser surface's navigation
  is, so `zenpay_flutter`'s `AppLinksReturnUriSource` never sees it — this class is what
  makes the return visible to `ZpCheckout` instead.
- `lib/src/render_checkout_web_view.dart` — `ZenPayCheckoutWebView`, the `webview_flutter`
  widget itself. Internal; constructed only by `EmbeddedCheckoutPresenter`.
- `lib/src/open_checkout_in_web_view.dart` — `EmbeddedCheckoutPresenter extends
  CheckoutPresenter`. Shows/dismisses its own modal bottom sheet via a
  `GlobalKey<NavigatorState>` supplied at construction, since `ZpCheckout.open` calls
  `openCheckout` without a `BuildContext` of its own.

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
