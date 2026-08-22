/// Embedded in-app WebView widget for ZenPay Hosted Checkout sessions.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:zenpay_embedded/src/navigation_policy.dart';
import 'package:zenpay_embedded/src/web_view_return_uri_source.dart';

/// State-attachment interface between [ZenPayCheckoutWebView] and
/// `EmbeddedCheckoutPresenter`.
///
/// Internal — not exported. `EmbeddedCheckoutPresenter` is the only caller;
/// merchants never construct or drive this widget directly.
abstract interface class EmbeddedStateInterface {
  /// Directs the mounted widget to load [url].
  void loadUrl(Uri url);

  /// Requests the mounted widget to clear its active page state.
  void clear();
}

/// Renders one ZenPay Hosted Checkout session inside an in-app WebView.
///
/// Always constructed by `EmbeddedCheckoutPresenter` as the content of a
/// modal bottom sheet it presents itself — never instantiated or placed in
/// a merchant's own widget tree directly, so there is exactly one correct
/// way to show it.
final class ZenPayCheckoutWebView extends StatefulWidget {
  /// Creates a [ZenPayCheckoutWebView].
  const ZenPayCheckoutWebView({
    required this.state,
    required this.returnUriSource,
    required this.returnUriAddress,
    super.key,
  });

  /// Receives the attach/detach lifecycle callbacks from the created state.
  final void Function(EmbeddedStateInterface state) state;

  /// The return URI source intercepted navigations are reported to.
  final WebViewReturnUriSource returnUriSource;

  /// The expected return URI address for matching intercepted redirects.
  ///
  /// This widget deliberately accepts no caller-supplied [WebViewController].
  /// [NavigationDelegate] and [JavaScriptMode] can be overridden on a
  /// controller after the fact, but JavaScript channels cannot be removed
  /// without knowing their names — so a caller-supplied controller with a
  /// channel already attached would hand the hosted payment page a native
  /// bridge that neither this widget nor the `lefthook` grep gate over
  /// `zenpay_embedded/lib` can see.
  final Uri returnUriAddress;

  @override
  State<ZenPayCheckoutWebView> createState() => _ZenPayCheckoutWebViewState();
}

final class _ZenPayCheckoutWebViewState extends State<ZenPayCheckoutWebView> implements EmbeddedStateInterface {
  /// Shown when the hosted page fails to load. Fixed text by design — see
  /// the [NavigationDelegate.onWebResourceError] handler.
  static const String _loadFailureMessage = 'Could not load the checkout page. Check your connection and try again.';

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController.fromPlatformCreationParams(
      WebViewPlatform.instance is AndroidWebViewPlatform ? AndroidWebViewControllerCreationParams() : const PlatformWebViewControllerCreationParams(),
    );
    _initController();
    unawaited(_enableGooglePayPaymentRequest());
    widget.state(this);
  }

  /// Google disables the Payment Request API in a `WebView` by default, so
  /// Google Pay fails inside the hosted checkout page unless the host app
  /// opts in per-platform. This is a native `WebSettings` flag, not a
  /// JavaScript channel — it carries none of the bridge risk the no-bridge
  /// rule guards against. iOS has no equivalent switch, so this is
  /// Android-only.
  Future<void> _enableGooglePayPaymentRequest() async {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController && await platform.isWebViewFeatureSupported(WebViewFeatureType.paymentRequest)) {
      await platform.setPaymentRequestEnabled(true);
    }
  }

  void _initController() {
    unawaited(_controller.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(
      _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              decideNavigation(request.url, returnUriAddress: widget.returnUriAddress, onReturnUri: widget.returnUriSource.addUri),
          onPageStarted: (url) {
            if (mounted && url != blankPage) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          // The platform's own description is deliberately discarded:
          // WebResourceError.description routinely embeds the failing URL,
          // which here is the checkout URL carrying the secure token.
          onWebResourceError: (error) {
            if (mounted && (error.isForMainFrame ?? true)) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      ),
    );
  }

  @override
  void loadUrl(Uri url) {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    unawaited(_controller.loadRequest(url));
  }

  /// Takes the hosted checkout off screen and discards its browsing state.
  ///
  /// Resetting the flags alone would leave the rendered card form visible
  /// after the presenter dismisses the sheet — including after a successful
  /// return, since `ZpCheckout.handleReturnUri` calls `dismissCheckout`.
  @override
  void clear() {
    unawaited(_discardBrowsingState());
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    }
  }

  /// Navigates away from the hosted page, then clears what it left behind.
  ///
  /// Ordered, not fired in parallel: the hosted page is live until it is
  /// replaced and would otherwise be free to re-set what was just cleared.
  ///
  /// **Every call here is app-wide, and there is no narrower option.**
  /// `webview_flutter` exposes no per-instance browsing-data store on either
  /// platform and no per-origin or session-only cookie removal, so
  /// dismissing checkout also signs out any other WebView in the host app —
  /// accepted deliberately, because the alternative is a live payment
  /// session surviving in shared storage. The system-browser default (Custom
  /// Tabs / `SFSafariViewController`, `zenpay_flutter`) gets this isolation
  /// from the OS and needs no teardown at all, which is why it stays the
  /// default presentation.
  Future<void> _discardBrowsingState() async {
    await _controller.loadRequest(Uri.parse(blankPage));
    await _controller.clearCache();
    await _controller.clearLocalStorage();
    await WebViewCookieManager().clearCookies();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: Text(_loadFailureMessage, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                }
                unawaited(_controller.reload());
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: <Widget>[
        WebViewWidget(controller: _controller),
        // Opaque and input-absorbing: a bare indicator would leave the
        // half-rendered hosted page visible and tappable while it loads.
        if (_isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}
