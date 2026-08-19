/// Platform default return URI source resolver for ZenPay Checkout.
///
/// Conditionally resolves [AppLinksReturnUriSource] for Mobile or
/// [WebPopupReturnUriSource] (`dart.library.js_interop`) for Web.
library;

import 'return_uri_source.dart';
import 'app_links_return_uri_source.dart'
    if (dart.library.js_interop) 'web_popup_return_uri_source.dart'
    as impl;

/// Creates a platform-specific default [ZpReturnUriSource] instance.
///
/// Returns a source listening for the `postMessage` handoff from a same-origin
/// checkout popup when compiled for Web, or one backed by `package:app_links`
/// App Links / Universal Links on Android and iOS.
ZpReturnUriSource createDefaultReturnUriSource() =>
    impl.createDefaultReturnUriSource();
