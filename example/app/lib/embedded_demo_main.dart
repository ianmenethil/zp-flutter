/// Standalone demo entry point for `zenpay_embedded`'s in-app WebView
/// checkout presentation.
///
/// A separate entry point rather than a mode inside `lib/main.dart`, so this
/// demo never touches that file. Renders the exact same `CheckoutPage` as
/// the real app — the only difference is which `CheckoutPresenter` gets
/// passed in, so this demo and `--android` are identical up to the pay
/// button.
///
/// Run via:
///
/// ```sh
/// dart run cli.dart --android-webview
/// ```
library;

import 'package:flutter/material.dart';
import 'package:zenpay_embedded/zenpay_embedded.dart';
import 'package:zenpay_example_app/core/config/app_config.dart';
import 'package:zenpay_example_app/core/theme/theme.dart';
import 'package:zenpay_example_app/features/checkout/ui/checkout_page.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

// Constructed once, outside the widget tree: CheckoutPage reads
// widget.presenter only in initState, so a presenter rebuilt on every
// _EmbeddedDemoApp.build() would leave the first one permanently in use
// while every later one leaked, unused and undisposed.
final _presenter = EmbeddedCheckoutPresenter(navigatorKey: _navigatorKey, returnUriAddress: appReturnUri);

void main() => runApp(const _EmbeddedDemoApp());

final class _EmbeddedDemoApp extends StatelessWidget {
  const _EmbeddedDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ZenPay Hosted Checkout',
      theme: ZenithTheme.light(),
      darkTheme: ZenithTheme.dark(),
      home: CheckoutPage(presenter: _presenter, returnUriSource: _presenter.returnUriSource),
    );
  }
}
