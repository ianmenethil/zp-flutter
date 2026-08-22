/// ZenPay Checkout Flutter SDK.
///
/// Provides secure, platform-native web checkout presentation and return
/// handling for Flutter applications across Android, iOS, and Web.
///
library;

export 'src/checkout/checkout_controller.dart';
// Only the predicate, never `ZpLaunchValidator` itself. A merchant surface
// that presents a checkout URL without going through `ZpCheckout.open`
// still has to apply the same host-and-scheme policy, and a second copy is
// how that check drifts.
export 'src/checkout/launch_validator.dart' show isAllowedCheckoutUrl;
export 'src/configuration/checkout_configuration.dart';
export 'src/exceptions/checkout_event.dart';
export 'src/models/checkout_outcome.dart';
export 'src/observability/checkout_event.dart';
// Lets an external package implement a custom presentation surface (e.g.
// an embedded WebView) and inject it via `ZpCheckout`'s optional `presenter`
// constructor parameter.
export 'src/presentation/presenter.dart';
export 'src/return_handling/mobile/app_links_return_uri_source.dart' hide createDefaultReturnUriSource;
export 'src/return_handling/return_uri_source.dart';
export 'src/return_handling/return_uri_source_factory.dart';
export 'src/return_handling/web/web_checkout_return_popup_factory.dart';
