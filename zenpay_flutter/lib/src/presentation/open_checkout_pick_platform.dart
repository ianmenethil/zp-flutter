/// Platform presenter resolver for ZenPay Checkout.
///
/// Conditionally imports and resolves the platform-appropriate [CheckoutPresenter]
/// implementation: Web (via `dart.library.js_interop`) or Mobile (`checkout_presenter_mobile.dart`).
library;

import 'package:zenpay_flutter/src/presentation/open_checkout_contract.dart';
import 'package:zenpay_flutter/src/presentation/open_checkout_on_mobile.dart' if (dart.library.js_interop) 'open_checkout_on_web.dart' as impl;

/// Creates a platform-specific [CheckoutPresenter] instance.
///
/// Returns a Web presenter backed by browser window navigation when compiled
/// for Web, or a Mobile presenter backed by `url_launcher` on Android and iOS.
CheckoutPresenter createCheckoutPresenter() => impl.createCheckoutPresenter();
