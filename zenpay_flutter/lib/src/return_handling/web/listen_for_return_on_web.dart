/// Web return URI source: receives the handoff posted by a same-origin
/// checkout return popup — see `web_checkout_return_popup.dart`.
///
/// On Web, [CheckoutPresenter.openCheckout] (`checkout_presenter_web.dart`)
/// presents ZenPay hosted checkout in a separate browser tab, so there is no
/// deep link or app link for `package:app_links` to observe in this tab —
/// the checkout tab never navigates this one. Instead, once the checkout tab
/// lands back on this app's own origin, it relays that landing here via
/// `postMessage` and closes itself. This class listens for that message.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:zenpay_flutter/src/presentation/open_checkout_contract.dart' show CheckoutPresenter;

import 'package:zenpay_flutter/src/return_handling/listen_for_return_contract.dart';
import 'package:zenpay_flutter/src/return_handling/web/web_return_protocol.dart';

@JS('addEventListener')
external void _addWindowMessageListener(String type, JSFunction listener);

@JS('removeEventListener')
external void _removeWindowMessageListener(String type, JSFunction listener);

@JS('location.origin')
external String get _locationOrigin;

/// The subset of `MessageEvent` this file reads.
extension type _MessageEvent(JSObject _) implements JSObject {
  external String get origin;
  external JSAny? get data;
}

/// [ZpReturnUriSource] receiving the return relayed by a same-origin
/// checkout popup — see this file's library doc comment.
final class WebPopupReturnUriSource implements ZpReturnUriSource {
  /// Creates a source and starts listening for `message` events immediately.
  WebPopupReturnUriSource() {
    _listener = ((JSAny event) => _onMessage(event as _MessageEvent)).toJS;
    _addWindowMessageListener('message', _listener);
    _controller.onCancel = () => _removeWindowMessageListener('message', _listener);
  }
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  late final JSFunction _listener;

  void _onMessage(_MessageEvent event) {
    final data = event.data;
    final messageData = (data != null && data.typeofEquals('string')) ? (data as JSString).toDart : null;
    final uri = parseIncomingReturnMessage(eventOrigin: event.origin, expectedOrigin: _locationOrigin, messageData: messageData);
    if (uri != null) _controller.add(uri);
  }

  @override
  Stream<Uri> get uris => _controller.stream;
}

/// Creates the platform-default [ZpReturnUriSource] for Web.
ZpReturnUriSource createDefaultReturnUriSource() => WebPopupReturnUriSource();
