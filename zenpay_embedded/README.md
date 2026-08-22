# zenpay_embedded

Optional embedded in-app WebView presentation for ZenPay Hosted Checkout.

Android Custom Tabs / iOS `SFSafariViewController` (`zenpay_flutter`) are the default
presentation and remain the recommended choice. This package is an explicit opt-in for
merchants who need checkout to appear inline, as a modal sheet, instead of switching to a
separate browser surface. Importing `zenpay_flutter` alone never pulls this package's
`webview_flutter` dependency into your app.

## Usage

```dart
final navigatorKey = GlobalKey<NavigatorState>(); // pass to MaterialApp(navigatorKey: ...)

final presenter = EmbeddedCheckoutPresenter(
  navigatorKey: navigatorKey,
  returnUriAddress: configuration.expectedReturnUri,
);

final checkout = ZpCheckout(
  configuration: configuration,
  returnUriSource: presenter.returnUriSource,
  presenter: presenter,
);

final outcome = await checkout.open(checkoutUrl: checkoutUrl);
```

`EmbeddedCheckoutPresenter` owns the entire presentation — it shows and dismisses its own
modal bottom sheet. There is no widget to place in your own tree and nothing to configure:
the same shape as the default Custom Tabs/Safari presenter, which also owns its surface
end-to-end.

Dispose the presenter alongside your `ZpCheckout` controller: `await presenter.dispose();`.

## WebView policy

An embedded WebView does not, by itself, change PCI scope in either direction — the hosted
page renders in the same engine either way, and the merchant application never handles card
data. What changes is the attack surface the host application exposes to that page. This
package enforces:

- **No JavaScript bridge to the hosted page.** `addJavaScriptChannel` and
  `setOnConsoleMessage` are barred by a `lefthook` pre-commit grep gate over this package's
  `lib/`, not by convention. On iOS, `webview_flutter` injects the JS-side shim for any
  channel with `isForMainFrameOnly: false`, and `WKUserContentController.add(_:name:)`
  registers the handler at the `WKWebViewConfiguration` level regardless — reachable from
  every frame the hosted page loads, including third-party 3DS/ACS frames, with no
  supported way to scope it narrower.
- **No caller-supplied `WebViewController`.** The internal widget builds its own controller;
  nothing external can attach a channel to it.
- **HTTPS-only navigation, no host allowlist on navigation.** 3DS sends the customer to
  issuer ACS hosts that cannot be enumerated in advance, so navigation is restricted to
  `https` rather than allowlisted by host. The host allowlist keeps its existing job:
  validating the checkout URL before launch (`isAllowedCheckoutUrl`, `zenpay_flutter`).
- **Full page navigation only.** The WebView's top-level document is always the ZenPay
  hosted page itself — never a merchant page with the checkout embedded as a sub-frame
  alongside merchant script. That coexistence (merchant script + PSP iframe in the same
  document) is what typically moves an integration from SAQ A to SAQ A-EP; it does not occur
  here.
- **Full teardown on dismiss.** Navigate to `about:blank`, then clear cache, local storage,
  and cookies, in that order. This is app-wide — `webview_flutter` exposes no per-instance
  browsing-data store on either platform — so dismissing checkout also signs out any other
  WebView in the host app. Accepted deliberately: the alternative is a live payment session
  surviving in shared storage.

**This package does not guarantee SAQ-A eligibility.** Scope and SAQ eligibility depend on
the merchant's complete environment, payment integration, provider status, and
acquirer/payment-brand rules, and must be confirmed with the merchant's acquirer and/or QSA.
