/// Typed results of a checkout presentation.
library;

import 'package:meta/meta.dart';

/// The result of one `ZpCheckout.open` call.
///
/// Exactly one of these settles a launch: a return arrived, the customer
/// dismissed the browser, the timeout elapsed, or the launch failed.
///
/// Every outcome describes what happened on the device and nothing more. None
/// of them is evidence that a payment succeeded — confirm that on the merchant
/// backend before fulfilling an order.
@immutable
sealed class const ZpCheckoutOutcome() {
  /// Stable, obfuscation-safe name for this outcome, for telemetry.
  ///
  /// Safe to log and to compare against; unlike `runtimeType` it survives
  /// release-mode minification unchanged.
  String get outcomeName => switch (this) {
    ZpReturnReceived() => 'returnReceived',
    ZpPresentationDismissed() => 'presentationDismissed',
    ZpTimedOut() => 'timedOut',
    ZpLaunchFailed() => 'launchFailed',
  };
}

/// A return URI arrived at the configured return address and passed validation.
final class const ZpReturnReceived({
  /// The validated, normalized return URI, query intact.
  ///
  /// Read whatever the merchant backend put there. The SDK does not interpret
  /// it and holds no opinion about which checkout it belongs to.
  required final Uri returnUri,
}) extends ZpCheckoutOutcome;

/// The customer closed the browser surface before any return arrived.
///
/// The payment may still have completed — a customer can dismiss the browser
/// after paying but before the redirect lands.
final class const ZpPresentationDismissed() extends ZpCheckoutOutcome;

/// Nothing settled the checkout before `ZpCheckoutConfiguration.timeout`.
///
/// Says only that the SDK stopped waiting. The payment may still be in flight.
final class const ZpTimedOut() extends ZpCheckoutOutcome;

/// The browser surface could not be opened, so checkout never started.
final class const ZpLaunchFailed({
  /// Which failure the platform reported.
  required final ZpLaunchFailureCode code,
}) extends ZpCheckoutOutcome;

/// Why a browser launch failed.
enum ZpLaunchFailureCode {
  /// No platform implementation of `url_launcher` was registered.
  platformUnavailable,

  /// The platform was asked to open the URL and declined.
  rejectedByPlatform,

  /// The platform threw an unexpected error while opening the URL.
  platformError,
}
