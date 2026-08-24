/// Pure validation logic for the Web return-popup handoff protocol.
///
/// Kept dependency-free of `dart:js_interop` deliberately: any file that
/// imports `dart:js_interop`, even indirectly, cannot be compiled by the
/// default VM `flutter test` platform at all ("Dart library 'dart:js_interop'
/// is not available on this platform"), so this security-relevant logic
/// (origin checks, address matching) has to live outside that import graph
/// to be unit tested.
library;

import 'package:zenpay_flutter/src/return_handling/validate_return_url.dart' show matchesReturnUriAddress;
import 'package:zenpay_flutter/src/return_handling/web/web_message_format.dart';

/// Decides whether an incoming `message` event is a valid return handoff and
/// decodes it — used by `WebPopupReturnUriSource`
/// (`web_popup_return_uri_source.dart`).
///
/// Only ever trusts a message from [expectedOrigin] — the return popup is
/// same-origin by construction. Returns `null` for a cross-origin event, a
/// non-handoff message, or a handoff whose href fails to parse.
Uri? parseIncomingReturnMessage({
  required String eventOrigin,
  required String expectedOrigin,
  required String? messageData,
}) {
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
/// Delegates to [matchesReturnUriAddress] (`return_validator.dart`) — the
/// same rules the app-level return validator applies — so a return URL that
/// would be rejected there can't first pass a laxer web-side check.
bool matchesReturnAddress(Uri current, Uri expected) => matchesReturnUriAddress(current, expected);
