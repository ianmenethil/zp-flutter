# zenpay_embedded

Optional in-app WebView presentation for ZenPay Hosted Checkout — a `CheckoutPresenter` for
`zenpay_flutter`'s `ZpCheckout`. The default presenter (Android Custom Tabs / iOS
`SFSafariViewController`, via `zenpay_flutter` alone) remains the recommended choice; use
this package only if checkout must render inline as a modal sheet instead. Importing
`zenpay_flutter` alone never pulls this package's `webview_flutter` dependency in.

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
// later, alongside checkout.dispose():
await presenter.dispose();
```

`EmbeddedCheckoutPresenter` owns its entire presentation — there is no widget to place in
your own tree and nothing else to configure.

## More

- PCI/WebView security policy this package enforces: [PCI_SAQ_A.md](https://github.com/ianmenethil/zp-flutter/blob/master/PCI_SAQ_A.md)
- Contributor source guide: [CLAUDE.md](CLAUDE.md)
- Repository: https://github.com/ianmenethil/zp-flutter
