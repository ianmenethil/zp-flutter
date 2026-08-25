/// Platform presentation interface for ZenPay Hosted Checkout.
///
/// Defines the internal contract for launching, reserving, and dismissing
/// checkout browser surfaces across supported Flutter platforms (Android, iOS, Web).
library;

import 'package:meta/meta.dart';

/// Result of attempting to present a checkout URL.
@immutable
final class PresentationLaunchResult {
  /// Creates a [PresentationLaunchResult].
  const PresentationLaunchResult({required this.launched, required this.usedExternalBrowserFallback});

  /// Whether the presentation was successfully launched.
  final bool launched;

  /// Whether launch fell back to an external system browser.
  final bool usedExternalBrowserFallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PresentationLaunchResult && other.launched == launched && other.usedExternalBrowserFallback == usedExternalBrowserFallback);

  @override
  int get hashCode => Object.hash(PresentationLaunchResult, launched, usedExternalBrowserFallback);
}

/// Presents the ZenPay hosted checkout page and reports its lifecycle.
abstract class CheckoutPresenter {
  /// Emits once each time the presentation surface is dismissed — by the
  /// user or the platform. No presenter implementation in this package
  /// distinguishes further event kinds (no `presentationStarted`, no
  /// `externalBrowserFallback`, no distinct `platformError`), so this is a
  /// plain signal stream rather than a typed event, which would carry a
  /// discriminant with only one possible value.
  Stream<void> get events;

  /// Presents [url], honouring [showTitle] and [allowExternalBrowserFallback]
  /// where the underlying platform supports them.
  Future<PresentationLaunchResult> openCheckout(Uri url, {required bool showTitle, required bool allowExternalBrowserFallback});

  /// Requests dismissal of the currently active presentation, if any.
  Future<bool> dismissCheckout();

  /// Reserves a presentation surface synchronously, before any `await`, for
  /// platforms whose presentation must be opened inside an unbroken user
  /// gesture (web's `window.open`). Call as the first step of a tap handler,
  /// before any asynchronous work such as requesting a checkout launch.
  ///
  /// The default implementation is a no-op that always succeeds — platforms
  /// without this constraint don't need to override it, and [openCheckout]
  /// behaves exactly as it does today.
  bool reserveLaunch() => true;

  /// Releases a reservation obtained via [reserveLaunch] without launching
  /// it — call when work between reservation and [openCheckout] fails.
  ///
  /// The default implementation is a no-op.
  void releaseReservation() {}
}
