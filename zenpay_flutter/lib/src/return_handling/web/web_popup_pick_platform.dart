/// Platform resolver for the checkout return popup handoff.
///
/// Conditionally resolves a no-op on Mobile or the real popup handoff
/// (`dart.library.js_interop`) on Web.
library;

import 'package:zenpay_flutter/src/return_handling/web/web_popup_not_used_on_mobile.dart'
    if (dart.library.js_interop) 'package:zenpay_flutter/src/return_handling/web/web_popup_sends_url_back.dart'
    as impl;

/// Call once, before running your app's normal widget tree — the very first
/// line of `main()`.
///
/// On Web, if this page was loaded as a same-origin checkout return popup
/// (see `web_checkout_return_popup.dart`), relays the return to the opener
/// and closes the window, returning `true` — `main()` should return
/// immediately rather than calling `runApp`. Otherwise — including always on
/// Mobile, where this concept doesn't apply — does nothing and returns
/// `false`.
bool completeWebCheckoutReturnIfPopup({required Uri expectedReturnUri}) => impl.completeWebCheckoutReturnIfPopup(expectedReturnUri: expectedReturnUri);
