/// ZenPay Checkout Flutter SDK.
///
/// Provides secure, platform-native web checkout presentation and return
/// handling for Flutter applications across Android, iOS, and Web.
///
library;

export 'src/checkout/run_checkout_flow.dart';
// Only the predicate, never `ZpLaunchValidator` itself. A merchant surface
// that presents a checkout URL without going through `ZpCheckout.open`
// still has to apply the same host-and-scheme policy, and a second copy is
// how that check drifts.
export 'src/checkout/validate_checkout_url.dart' show isAllowedCheckoutUrl;
export 'src/configuration/checkout_settings.dart';
export 'src/exceptions/checkout_errors.dart';
export 'src/models/checkout_results.dart';
export 'src/observability/checkout_telemetry.dart';
// Lets an external package implement a custom presentation surface (e.g.
// an embedded WebView) and inject it via `ZpCheckout`'s optional `presenter`
// constructor parameter.
export 'src/presentation/open_checkout_contract.dart';
export 'src/return_handling/listen_for_return_contract.dart';
export 'src/return_handling/listen_for_return_pick_platform.dart';
export 'src/return_handling/mobile/listen_for_return_on_mobile.dart' hide createDefaultReturnUriSource;
export 'src/return_handling/web/web_popup_pick_platform.dart';
