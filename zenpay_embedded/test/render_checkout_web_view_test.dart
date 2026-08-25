/// Widget tests for `render_checkout_web_view.dart`'s `ZenPayCheckoutWebView`.
///
/// Drives it via the shared `FakeWebViewPlatform` in `support/fake_webview_platform.dart`
/// — see that file's doc comment for why faking `WebViewPlatform.instance` works.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:zenpay_embedded/src/decide_web_view_navigation.dart' show blankPage;
import 'package:zenpay_embedded/src/listen_for_return_in_web_view.dart';
import 'package:zenpay_embedded/src/render_checkout_web_view.dart';

import 'support/fake_webview_platform.dart';

void main() {
  late FakeWebViewPlatform platform;
  late WebViewReturnUriSource returnUriSource;
  final returnUriAddress = Uri.parse('https://app.example.com/return');

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    returnUriSource = WebViewReturnUriSource();
  });

  tearDown(() async {
    await returnUriSource.dispose();
  });

  Future<EmbeddedStateInterface> pumpWebView(WidgetTester tester) async {
    EmbeddedStateInterface? state;
    await tester.pumpWidget(
      MaterialApp(
        home: ZenPayCheckoutWebView(state: (s) => state = s, returnUriSource: returnUriSource, returnUriAddress: returnUriAddress),
      ),
    );
    await tester.pump();
    return state!;
  }

  testWidgets('shows a loading indicator on initial build', (tester) async {
    await pumpWebView(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('onPageStarted for a real URL re-shows the loading indicator', (tester) async {
    await pumpWebView(tester);
    platform.delegate!.onPageFinished!('https://checkout.example/pay');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platform.delegate!.onPageStarted!('https://checkout.example/pay');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('onPageStarted for blankPage does not re-show the loading indicator', (tester) async {
    await pumpWebView(tester);
    platform.delegate!.onPageFinished!('https://checkout.example/pay');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platform.delegate!.onPageStarted!(blankPage);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('onPageFinished hides the loading indicator', (tester) async {
    await pumpWebView(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    platform.delegate!.onPageFinished!('https://checkout.example/pay');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a main-frame resource error shows the failure UI, and Try again reloads', (tester) async {
    await pumpWebView(tester);

    platform.delegate!.onWebResourceError!(const WebResourceError(errorCode: -2, description: 'boom', isForMainFrame: true));
    await tester.pump();

    expect(find.text('Could not load the checkout page. Check your connection and try again.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(platform.controller!.calls, contains('reload'));
  });

  testWidgets('a non-main-frame resource error is ignored', (tester) async {
    await pumpWebView(tester);

    platform.delegate!.onWebResourceError!(const WebResourceError(errorCode: -2, description: 'sub-frame boom', isForMainFrame: false));
    await tester.pump();

    expect(find.text('Could not load the checkout page. Check your connection and try again.'), findsNothing);
  });

  testWidgets('loadUrl loads the request and resets to a non-error loading state', (tester) async {
    final state = await pumpWebView(tester);
    platform.delegate!.onWebResourceError!(const WebResourceError(errorCode: -2, description: 'boom', isForMainFrame: true));
    await tester.pump();

    state.loadUrl(Uri.parse('https://checkout.example/pay'));
    await tester.pump();

    expect(platform.controller!.calls, contains('loadRequest:https://checkout.example/pay'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('clear discards browsing state in order and resets to non-loading, non-error', (tester) async {
    final state = await pumpWebView(tester);

    state.clear();
    await tester.pump();

    expect(platform.controller!.calls, ['loadRequest:$blankPage', 'clearCache', 'clearLocalStorage']);
    expect(platform.cookieManager!.clearCookiesCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Could not load the checkout page. Check your connection and try again.'), findsNothing);
  });

  testWidgets('onNavigationRequest is wired to the navigation delegate', (tester) async {
    await pumpWebView(tester);

    final decision = await platform.delegate!.onNavigationRequest!(const NavigationRequest(url: 'https://checkout.example/pay', isMainFrame: true));

    expect(decision, NavigationDecision.navigate);
  });
}
