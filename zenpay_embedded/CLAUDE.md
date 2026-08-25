# zenpay_embedded — Optional In-App WebView Presenter

Optional in-app WebView presentation for ZenPay Hosted Checkout, via `webview_flutter`. Not
the default — `zenpay_flutter`'s Android Custom Tabs / iOS `SFSafariViewController`
presenter is — this package exists for merchants who explicitly need inline/modal checkout
instead. Full PCI/WebView security policy (why Custom Tabs/Safari is the safer default,
every control this package enforces, which are backed by `lefthook` regression gates):
[PCI_SAQ_A.md](../PCI_SAQ_A.md). Do not promise SAQ-A eligibility anywhere in this
package's docs — that determination sits with the merchant's acquirer/QSA.

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[zenpay_flutter](../zenpay_flutter/CLAUDE.md)** — The SDK this package depends on: `CheckoutPresenter` (the contract implemented here) and `ZpReturnUriSource`.
- **[PCI_SAQ_A.md](../PCI_SAQ_A.md)** — The full WebView security policy this package enforces.
- **[README.md](README.md)** — Usage.

## Source Guide

- **`lib/src/decide_web_view_navigation.dart`** — Navigation policy: blocks every non-HTTPS scheme, never allowlists by host (3DS/issuer ACS hosts can't be enumerated in advance).
- **`lib/src/listen_for_return_in_web_view.dart`** — `WebViewReturnUriSource`: feeds return URIs intercepted from in-WebView navigation, since App Links/Universal Links never see navigation that stays inside a WebView.
- **`lib/src/render_checkout_web_view.dart`** — The `webview_flutter` widget: never accepts a caller-supplied `WebViewController`, never calls `addJavaScriptChannel`/`setOnConsoleMessage` (barred by the `no-js-bridge` lefthook gate), full teardown (cache/local storage/cookies) on dismiss.
- **`lib/src/open_checkout_in_web_view.dart`** — `EmbeddedCheckoutPresenter`: owns its modal bottom sheet end-to-end, the same shape as the default presenter's surface ownership.
- **`lib/zenpay_embedded.dart`** — Barrel export: only `EmbeddedCheckoutPresenter`. Everything else stays internal/unexported deliberately — no widget for a merchant to embed directly.

## Verification

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```

Confirm the JS-bridge gate fires: temporarily add `addJavaScriptChannel` under `lib/`, run
`grep -rn -e "addJavaScriptChannel" -e "setOnConsoleMessage" zenpay_embedded/lib` (what
`lefthook.yml`'s `no-js-bridge` command runs), confirm it's found, then remove it.
