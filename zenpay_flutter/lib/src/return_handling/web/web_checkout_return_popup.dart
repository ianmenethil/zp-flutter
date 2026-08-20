/// Completes a checkout return when this page was loaded as a same-origin
/// popup opened by [CheckoutPresenter.openCheckout] — see
/// `checkout_presenter_web.dart` and `web_popup_return_uri_source.dart`.
library;

import 'dart:js_interop';

import 'package:zenpay_flutter/src/presentation/presenter.dart' show CheckoutPresenter;

import 'package:zenpay_flutter/src/return_handling/web/web_return_message.dart';
import 'package:zenpay_flutter/src/return_handling/web/web_return_validation.dart';

@JS('opener')
external JSObject? get _opener;

@JS('location.href')
external String get _locationHref;

@JS('close')
external void _closeWindow();

extension type _Opener(JSObject _) implements JSObject {
  external void postMessage(JSAny message, String targetOrigin);
}

/// Call once, before running your app's normal widget tree — the very first line of `main()` on Web.
///
/// If this page is the popup — it has a same-origin `window.opener` and its
/// current address matches [expectedReturnUri] — this relays the current URL
/// to the opener via `postMessage`, closes the window, and returns `true`;
/// `main()` should return immediately rather than calling `runApp`.
/// Otherwise this does nothing and returns `false`.
bool completeWebCheckoutReturnIfPopup({required Uri expectedReturnUri}) {
  final opener = _opener;
  if (opener == null) return false;

  final current = Uri.parse(_locationHref);
  if (!matchesReturnAddress(current, expectedReturnUri)) return false;

  _Opener(opener).postMessage(encodeZpReturnMessage(_locationHref).toJS, current.origin);
  _closeWindow();
  return true;
}
