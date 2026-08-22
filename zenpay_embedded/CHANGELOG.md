## 0.1.0

- Initial release: `ZenPayCheckoutWebView`, an opt-in embedded in-app WebView
  presentation for ZenPay Hosted Checkout on Android and iOS, implementing
  `zenpay_flutter`'s `CheckoutPresenter` contract via
  `EmbeddedCheckoutPresenter`.
- No JavaScript bridge to the hosted page: `addJavaScriptChannel` and
  `setOnConsoleMessage` are barred by a `lefthook` pre-commit grep gate, not
  by convention.
- No caller-supplied `WebViewController` — the widget owns its controller
  internally so a bridge cannot be attached past the gate above.
- HTTPS-only navigation with return-URI interception
  (`WebViewReturnUriSource`); no host allowlist on navigation, since 3DS
  sends the customer to issuer ACS hosts that cannot be enumerated in
  advance.
- Full browsing-state teardown on dismiss: navigate to `about:blank`, then
  clear cache, local storage, and cookies, in that order.
- Not a default presentation — Android Custom Tabs / iOS
  `SFSafariViewController` (`zenpay_flutter`) remain the default; this
  package is an explicit opt-in with its own dependency footprint.
