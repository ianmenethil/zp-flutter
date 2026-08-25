/// Shared `WebViewPlatform` fake for widget-testing `ZenPayCheckoutWebView`
/// and anything that presents it, without a real platform channel.
///
/// `WebViewPlatform.instance` is a swappable static, the same pattern
/// `zenpay_flutter`'s tests already use to fake `UrlLauncherPlatform.instance`
/// for `url_launcher`. This fake implements only the members
/// `render_checkout_web_view.dart` actually calls; everything else keeps the
/// platform interface's default `UnimplementedError`.
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

final class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  final List<String> calls = [];

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    calls.add('loadRequest:${params.uri}');
  }

  @override
  Future<void> reload() async => calls.add('reload');

  @override
  Future<void> clearCache() async => calls.add('clearCache');

  @override
  Future<void> clearLocalStorage() async => calls.add('clearLocalStorage');
}

final class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {
    this.onNavigationRequest = onNavigationRequest;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {
    this.onPageStarted = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async {
    this.onWebResourceError = onWebResourceError;
  }
}

final class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params) : super.implementation();

  int clearCookiesCalls = 0;

  @override
  Future<bool> clearCookies() async {
    clearCookiesCalls++;
    return true;
  }
}

/// Captures the one controller/delegate/cookie-manager each widget under
/// test creates, so a test can drive their callbacks and inspect their calls.
final class FakeWebViewPlatform extends WebViewPlatform {
  FakeWebViewController? controller;
  FakeNavigationDelegate? delegate;
  FakeCookieManager? cookieManager;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) => controller = FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) => delegate = FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) => FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(PlatformWebViewCookieManagerCreationParams params) => cookieManager = FakeCookieManager(params);
}
