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

## Testing

`render_checkout_web_view_test.dart` and `open_checkout_in_web_view_test.dart` drive the
in-app WebView through a fake `WebViewPlatform` (`test/support/fake_webview_platform.dart`)
— the same swappable-static pattern `zenpay_flutter`'s tests use to fake
`UrlLauncherPlatform.instance` for `url_launcher` — so no real platform channel or device is
needed.

**Coverage:** 91.0% line coverage. Regenerate with `melos run coverage --scope=zenpay_embedded` from the repository root — writes `zenpay_embedded/coverage/lcov.info`.

## WebView policy

An embedded WebView does not, by itself, change PCI scope in either direction — the hosted
page renders in the same engine either way, and the merchant application never handles card
data. What changes is the attack surface the host application exposes to that page, and this
package enforces that surface stays minimal.

📐 **See [PCI_SAQ_A.md](../PCI_SAQ_A.md)** for the full policy: why the default Custom
Tabs/Safari presenter is the safer architectural choice in the first place, every control
this package enforces (JS bridge, controller ownership, navigation policy, full-page-only
navigation, teardown on dismiss, Google Pay), which ones are backed by `lefthook` regression
guards, and the outstanding compliance gates that remain before embedded mode can be
advertised as SAQ-A-compatible. This package does not, on its own, guarantee SAQ-A
eligibility — that determination sits with the merchant's acquirer and/or QSA.
