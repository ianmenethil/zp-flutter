/// The `postMessage` string protocol between a checkout return popup and its
/// opener, both always same-origin by construction — see
/// `web_checkout_return_popup.dart` (sender) and
/// `web_popup_return_uri_source.dart` (receiver).
library;

const _prefix = 'zenpay:checkout-return:';

/// Wraps [href] as a return handoff message payload.
String encodeZpReturnMessage(String href) => '$_prefix$href';

/// Unwraps a return handoff message, or `null` if [message] isn't one.
String? decodeZpReturnMessage(String message) => message.startsWith(_prefix) ? message.substring(_prefix.length) : null;
