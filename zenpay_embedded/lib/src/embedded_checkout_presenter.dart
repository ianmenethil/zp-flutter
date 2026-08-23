/// Presenter implementation backing the embedded in-app WebView mode.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zenpay_embedded/src/web_view_return_uri_source.dart';
import 'package:zenpay_embedded/src/zenpay_checkout_web_view.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

/// Presents ZenPay Hosted Checkout in an in-app WebView, inside a modal
/// bottom sheet this presenter shows and dismisses itself.
///
/// Owns the entire presentation surface — sizing, scroll behavior, and
/// teardown — the same way `zenpay_flutter`'s Custom Tabs/`SFSafariViewController`
/// presenter owns its surface. There is no widget for a merchant to place in
/// their own tree and no bottom sheet for them to configure.
///
/// Requires the [GlobalKey<NavigatorState>] already attached to the host
/// app's `MaterialApp`/`WidgetsApp`, since [ZpCheckout.open] calls
/// [openCheckout] without a `BuildContext` of its own.
final class EmbeddedCheckoutPresenter extends CheckoutPresenter {
  /// Creates an [EmbeddedCheckoutPresenter].
  ///
  /// [returnUriAddress] should be the same [Uri] as the owning
  /// [ZpCheckout]'s `configuration.expectedReturnUri`.
  EmbeddedCheckoutPresenter({required this.navigatorKey, required Uri returnUriAddress})
    : // An initializing formal here would make the private field name
      // (`_returnUriAddress`) the public named parameter, which external
      // callers cannot reference — so this explicit initializer is
      // required, not a style choice.
      // ignore: prefer_initializing_formals
      _returnUriAddress = returnUriAddress,
      returnUriSource = WebViewReturnUriSource();

  /// The host app's root navigator key, used to present the bottom sheet
  /// without a `BuildContext` supplied at the [openCheckout] call site.
  final GlobalKey<NavigatorState> navigatorKey;

  final Uri _returnUriAddress;

  /// The return URI source fed by intercepted WebView navigation.
  ///
  /// Pass this same instance as the owning [ZpCheckout]'s `returnUriSource`
  /// — constructing a second [WebViewReturnUriSource] would silently never
  /// receive the returns this presenter's WebView intercepts.
  final WebViewReturnUriSource returnUriSource;

  final StreamController<void> _events = StreamController<void>.broadcast();

  EmbeddedStateInterface? _mountedState;
  Uri? _pendingUrl;
  bool _sheetOpen = false;

  @override
  Stream<void> get events => _events.stream;

  /// Presents [url] in a modal bottom sheet hosting the embedded WebView.
  ///
  /// [showTitle] and [allowExternalBrowserFallback] have no equivalent in
  /// this presentation mode — there is no browser chrome and no external
  /// browser fallback for an in-app WebView — and are accepted only to
  /// satisfy the [CheckoutPresenter] contract.
  @override
  Future<PresentationLaunchResult> openCheckout(Uri url, {required bool showTitle, required bool allowExternalBrowserFallback}) async {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      return const PresentationLaunchResult(launched: false, usedExternalBrowserFallback: false);
    }

    _pendingUrl = url;
    _sheetOpen = true;
    unawaited(
      showModalBottomSheet<void>(
        context: navigatorState.context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: ZenPayCheckoutWebView(state: _attachState, returnUriSource: returnUriSource, returnUriAddress: _returnUriAddress),
        ),
      ).whenComplete(_onSheetClosed),
    );

    return const PresentationLaunchResult(launched: true, usedExternalBrowserFallback: false);
  }

  void _attachState(EmbeddedStateInterface state) {
    _mountedState = state;
    final pending = _pendingUrl;
    if (pending != null) {
      _pendingUrl = null;
      state.loadUrl(pending);
    }
  }

  /// Fires when the sheet's route completes — a user swipe/tap-outside
  /// dismissal, or the [Navigator.pop] issued by [dismissCheckout].
  ///
  /// Guarded by [_sheetOpen] rather than firing unconditionally: by the time
  /// this callback runs after a return-triggered [dismissCheckout],
  /// `ZpCheckout`'s active checkout has already settled and cancelled its
  /// subscription to [events] (`ActiveCheckout.finish` — first call wins),
  /// so emitting again here would be harmless but is skipped anyway.
  void _onSheetClosed() {
    _mountedState = null;
    if (_sheetOpen) {
      _sheetOpen = false;
      _events.add(null);
    }
  }

  @override
  Future<bool> dismissCheckout() async {
    if (!_sheetOpen) {
      return false;
    }
    _mountedState?.clear();
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
    }
    return true;
  }

  /// Closes this presenter's event stream and its [returnUriSource].
  ///
  /// Call once, when the owning `ZpCheckout` is disposed.
  Future<void> dispose() async {
    await _events.close();
    await returnUriSource.dispose();
  }
}
