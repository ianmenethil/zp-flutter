/// The `postMessage` handoff protocol between a checkout return popup and its
/// opener, both always same-origin by construction — see
/// `web_checkout_return_popup.dart` (sender) and
/// `web_popup_return_uri_source.dart` (receiver).
///
/// Kept dependency-free of `dart:js_interop` deliberately: any file that
/// imports `dart:js_interop`, even indirectly, cannot be compiled by the
/// default VM `flutter test` platform at all ("Dart library 'dart:js_interop'
/// is not available on this platform"), so this security-relevant logic
/// (message format, origin checks, address matching) has to live outside
/// that import graph to be unit tested.
library;

import 'package:zenpay_flutter/src/return_handling/validate_return_url.dart' show matchesReturnUriAddress;

const _prefix = 'zenpay:checkout-return:';

/// Wraps [href] as a return handoff message payload.
String encodeZpReturnMessage(String href) => '$_prefix$href';

/// Unwraps a return handoff message, or `null` if [message] isn't one.
String? decodeZpReturnMessage(String message) => message.startsWith(_prefix) ? message.substring(_prefix.length) : null;

/// Decides whether an incoming `message` event is a valid return handoff and
/// decodes it — used by `WebPopupReturnUriSource`
/// (`web_popup_return_uri_source.dart`).
///
/// Only ever trusts a message from [expectedOrigin] — the return popup is
/// same-origin by construction. Returns `null` for a cross-origin event, a
/// non-handoff message, or a handoff whose href fails to parse.
Uri? parseIncomingReturnMessage({required String eventOrigin, required String expectedOrigin, required String? messageData}) {
  if (eventOrigin != expectedOrigin) return null;
  if (messageData == null) return null;
  final href = decodeZpReturnMessage(messageData);
  if (href == null) return null;
  try {
    return Uri.parse(href);
  } on FormatException {
    return null;
  }
}

/// Whether [current] is the popup's expected return address — used by
/// `completeWebCheckoutReturnIfPopup` (`web_checkout_return_popup.dart`).
///
/// Delegates to [matchesReturnUriAddress] (`validate_return_url.dart`) — the
/// same rules the app-level return validator applies — so a return URL that
/// would be rejected there can't first pass a laxer web-side check.
bool matchesReturnAddress(Uri current, Uri expected) => matchesReturnUriAddress(current, expected);
