/// Navigation policy for the embedded checkout WebView.
///
/// Kept out of the widget because a [NavigationDelegate] cannot be driven
/// without a `WebViewPlatform`, and this is the half worth testing: it is
/// what stops the hosted page navigating off `https`, and what recognises
/// the return redirect before the WebView can follow it.
library;

import 'package:webview_flutter/webview_flutter.dart';

/// The inert page the widget loads to take the hosted checkout off screen.
const String blankPage = 'about:blank';

/// Whether [candidate]'s scheme, host, port, and path match [expected].
///
/// A navigation-control heuristic only — deliberately looser than
/// `zenpay_flutter`'s internal `ZpReturnValidator` (query length, malformed
/// query, and duplicate-key checks are not repeated here). This function
/// only decides whether the WebView should stop navigating and hand the URI
/// to `WebViewReturnUriSource`; the authoritative accept/reject decision is
/// made downstream by `ZpCheckout.handleReturnUri`, which every emitted URI
/// still passes through.
bool _looksLikeReturnUri(Uri candidate, Uri expected) {
  return candidate.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
      candidate.host.toLowerCase() == expected.host.toLowerCase() &&
      candidate.port == expected.port &&
      candidate.path == expected.path;
}

/// Decides whether the embedded WebView may follow [url].
///
/// Calls [onReturnUri] exactly when [url] matches [returnUriAddress] and
/// then prevents the navigation — the redirect itself is the signal, and
/// following it would leave the merchant's own return page rendered inside
/// the checkout sheet with no way back.
///
/// Not exported from the package barrel: this is an internal rule, not API.
NavigationDecision decideNavigation(
  String url, {
  required Uri returnUriAddress,
  required void Function(Uri uri) onReturnUri,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return NavigationDecision.prevent;
  }

  // `about:blank` carries no content and no origin. The widget loads it to
  // take the rendered card form off screen, so it is allowed past the
  // https-only rule below rather than being blocked by it.
  if (uri.toString() == blankPage) {
    return NavigationDecision.navigate;
  }

  // Everything else must be https. This is what keeps the hosted page from
  // handing the WebView an `intent://`, `file://` or `javascript:` URL — and
  // it cannot be narrowed to a host allowlist, because a 3DS challenge sends
  // the customer to their own issuer's ACS host, which cannot be enumerated
  // in advance.
  if (uri.scheme.toLowerCase() != 'https') {
    return NavigationDecision.prevent;
  }

  if (_looksLikeReturnUri(uri, returnUriAddress)) {
    onReturnUri(uri);
    return NavigationDecision.prevent;
  }

  return NavigationDecision.navigate;
}
