/// Platform default return URI source resolver for ZenPay Checkout.
///
/// Conditionally resolves AppLinksReturnUriSource for Mobile or
/// `WebPopupReturnUriSource` (`dart.library.js_interop`) for Web.
library;

import 'package:zenpay_flutter/src/return_handling/listen_for_return_contract.dart';
import 'package:zenpay_flutter/src/return_handling/mobile/listen_for_return_on_mobile.dart'
    if (dart.library.js_interop) 'package:zenpay_flutter/src/return_handling/web/listen_for_return_on_web.dart'
    as impl;

/// Creates a platform-specific default [ZpReturnUriSource] instance.
///
/// Returns a source listening for the `postMessage` handoff from a same-origin
/// checkout popup when compiled for Web, or one backed by `package:app_links`
/// App Links / Universal Links on Android and iOS.
ZpReturnUriSource createDefaultReturnUriSource() => impl.createDefaultReturnUriSource();
