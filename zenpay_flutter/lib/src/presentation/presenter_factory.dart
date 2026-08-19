/// Platform presenter resolver for ZenPay Checkout.
///
/// Conditionally imports and resolves the platform-appropriate [CheckoutPresenter]
/// implementation: Web (via `dart.library.js_interop`) or Mobile (`checkout_presenter_mobile.dart`).
library;

import 'presenter.dart';
import 'checkout_presenter_mobile.dart'
    if (dart.library.js_interop) 'checkout_presenter_web.dart'
    as impl;

/// Creates a platform-specific [CheckoutPresenter] instance.
///
/// Returns a Web presenter backed by browser window navigation when compiled
/// for Web, or a Mobile presenter backed by `url_launcher` on Android and iOS.
CheckoutPresenter createCheckoutPresenter() => impl.createCheckoutPresenter();
