/// Mobile stand-in for `web_checkout_return_popup.dart` — the popup handoff
/// is a Web-only concept, so this never intercepts.
library;

/// Always returns `false`: mobile presents checkout in a platform browser
/// surface, not a popup, so there is nothing here to hand off.
bool completeWebCheckoutReturnIfPopup({required Uri expectedReturnUri}) => false;
