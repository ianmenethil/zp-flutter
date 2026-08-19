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

import 'return_uri_source.dart';
import 'web_return_message.dart';

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
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();
  late final JSFunction _listener;

  /// Creates a source and starts listening for `message` events immediately.
  WebPopupReturnUriSource() {
    _listener = ((JSAny event) => _onMessage(event as _MessageEvent)).toJS;
    _addWindowMessageListener('message', _listener);
    _controller.onCancel = () =>
        _removeWindowMessageListener('message', _listener);
  }

  void _onMessage(_MessageEvent event) {
    // Only ever trust a message from this exact page's own origin — the
    // return popup is same-origin by construction (see the library doc).
    if (event.origin != _locationOrigin) return;
    final data = event.data;
    if (data == null || !data.typeofEquals('string')) return;
    final href = decodeZpReturnMessage((data as JSString).toDart);
    if (href == null) return;
    try {
      _controller.add(Uri.parse(href));
    } on FormatException {
      // Malformed href: nothing to recover, ignore like any other
      // unrecognized message.
    }
  }

  @override
  Stream<Uri> get uris => _controller.stream;
}

/// Creates the platform-default [ZpReturnUriSource] for Web.
ZpReturnUriSource createDefaultReturnUriSource() => WebPopupReturnUriSource();
