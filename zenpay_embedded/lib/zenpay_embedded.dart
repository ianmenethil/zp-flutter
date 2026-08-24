/// Optional embedded in-app WebView presentation for ZenPay Hosted Checkout.
///
/// Not a default presentation — see `zenpay_flutter` for the default Android
/// Custom Tabs / iOS `SFSafariViewController` presenter. This package is an
/// explicit opt-in with its own `webview_flutter` dependency footprint;
/// merchants who never import it never resolve that dependency at all.
library;

export 'src/open_checkout_in_web_view.dart';
