/// Return URI source backed by intercepted WebView navigation.
library;

import 'dart:async';

import 'package:zenpay_flutter/zenpay_checkout.dart';

/// A [ZpReturnUriSource] fed by return URIs intercepted from
/// `ZenPayCheckoutWebView`'s navigation delegate, rather than by OS-level
/// App Links/Universal Links.
///
/// A navigation happening entirely inside an in-process WebView is not
/// handed off to the platform's App Link/Universal Link resolver the way a
/// system browser surface's navigation is — so `zenpay_flutter`'s
/// `AppLinksReturnUriSource` never sees it. This class is what makes the
/// return visible to `ZpCheckout` instead.
final class WebViewReturnUriSource implements ZpReturnUriSource {
  /// Creates a [WebViewReturnUriSource].
  WebViewReturnUriSource({StreamController<Uri>? controller}) : _controller = controller ?? StreamController<Uri>.broadcast();

  final StreamController<Uri> _controller;

  @override
  Stream<Uri> get uris => _controller.stream;

  /// Emits an intercepted return [uri] into the stream.
  ///
  /// [ZpCheckout] applies its own authoritative validation
  /// (`ZpReturnValidator`) to every URI received here — this class performs
  /// no validation of its own.
  void addUri(Uri uri) {
    if (!_controller.isClosed) {
      _controller.add(uri);
    }
  }

  /// Closes the underlying stream controller.
  Future<void> dispose() async {
    await _controller.close();
  }
}
