/// Presents ZenPay checkout in a platform-native browser surface and resolves
/// the launch with a single [ZpCheckoutOutcome].
///
/// Lifecycle:
/// 1. Reserve a presentation surface synchronously (preserves the web gesture).
/// 2. Validate the checkout URL against the configured host allowlist.
/// 3. Present in a platform-native browser surface.
/// 4. Listen for incoming return URIs and dismissal events.
/// 5. Settle on the first of: return, dismissal, timeout, launch failure.
/// 6. Emit structured events to a [ZpCheckoutObserver].
///
/// The controller holds only the state of the launch currently in flight, and
/// discards it the moment that launch settles. It persists nothing and knows
/// nothing about orders, payments or sessions. Deciding which payment a return
/// belongs to, and whether it can be trusted, is the integrating application's
/// job — see `createZpCallbackUrlToken` in `zenpay_dart` for one stateless way
/// to do it.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:zenpay_flutter/src/checkout/track_active_checkout.dart';
import 'package:zenpay_flutter/src/checkout/validate_checkout_url.dart';
import 'package:zenpay_flutter/src/configuration/checkout_settings.dart';
import 'package:zenpay_flutter/src/exceptions/checkout_errors.dart';
import 'package:zenpay_flutter/src/models/checkout_results.dart';
import 'package:zenpay_flutter/src/observability/checkout_telemetry.dart';
import 'package:zenpay_flutter/src/presentation/open_checkout_contract.dart';
import 'package:zenpay_flutter/src/presentation/open_checkout_pick_platform.dart';
import 'package:zenpay_flutter/src/return_handling/listen_for_return_contract.dart';
import 'package:zenpay_flutter/src/return_handling/validate_return_url.dart';

/// Maps a launch failure thrown by `url_launcher` onto a [ZpLaunchFailureCode].
///
/// `url_launcher` does not provide plugin-specific failure error codes:
/// - When a platform implementation is missing, it throws
///   [MissingPluginException], mapped to
///   [ZpLaunchFailureCode.platformUnavailable].
/// - Any other error is treated as an unexpected
///   [ZpLaunchFailureCode.platformError].
/// - When `launchUrl` returns `false`, it is handled separately as
///   [ZpLaunchFailureCode.rejectedByPlatform].
ZpLaunchFailureCode mapLaunchFailureCode(Object error) => switch (error) {
  MissingPluginException() => ZpLaunchFailureCode.platformUnavailable,
  _ => ZpLaunchFailureCode.platformError,
};

/// Presents ZenPay checkout and resolves the result.
///
/// Opens the checkout page in a platform-native browser surface (Chrome Custom
/// Tabs on Android, `SFSafariViewController` on iOS, a new tab on Web), watches
/// for dismissal or timeout, intercepts incoming return URIs, and resolves with
/// a [ZpCheckoutOutcome].
///
/// One checkout may be active per instance. Calling [open] while another is in
/// progress throws [ZpCheckoutAlreadyActiveException].
final class ZpCheckout {
  /// Creates a [ZpCheckout] controller instance.
  ///
  /// Requires a [configuration] specifying allowlisted hosts and the expected
  /// return URI, and a [ZpReturnUriSource] delivering incoming deep links. An
  /// optional [presenter] can be supplied for testing or a custom presentation
  /// strategy.
  ZpCheckout({required this.configuration, required this._returnUriSource, CheckoutPresenter? presenter}) : _presenter = presenter ?? createCheckoutPresenter();

  /// The active checkout configuration settings.
  final ZpCheckoutConfiguration configuration;
  final ZpReturnUriSource _returnUriSource;
  final CheckoutPresenter _presenter;
  final ZpLaunchValidator _launchValidator = const ZpLaunchValidator();
  final ZpReturnValidator _returnValidator = const ZpReturnValidator();

  ActiveCheckout? _active;
  bool _disposed = false;

  /// Whether `_presenter.openCheckout(...)` is currently awaited for
  /// [_active]. See [dispose]'s use of this — a browser that hasn't finished
  /// opening yet can't be dismissed, and finishing early would cancel the
  /// return-uri subscription before a return that's already in flight can
  /// land.
  bool _presentationInFlight = false;

  /// Reserves a presentation surface synchronously before any `await`.
  ///
  /// On Web, browsers require `window.open` to execute synchronously within an
  /// unbroken user gesture (e.g. in the immediate click/tap handler). Call this
  /// as the very first step of the checkout button handler, before requesting a
  /// checkout URL from the merchant backend.
  ///
  /// Returns `true` if a surface was reserved, or if the current platform needs
  /// no reservation. The caller must then go on to call [open] (which consumes
  /// the reservation) or [releaseLaunchReservation] (if the backend request
  /// fails).
  ///
  /// Returns `false` if the platform blocked reservation, e.g. a popup blocker.
  /// The caller must not call [open] in that case.
  bool reserveLaunch() => _presenter.reserveLaunch();

  /// Releases a presentation surface previously acquired via [reserveLaunch].
  ///
  /// Call this if anything fails between reserving the surface and calling
  /// [open] — a failed network request for the checkout URL, for instance — so
  /// that a reserved blank window or tab is closed rather than left open.
  void releaseLaunchReservation() => _presenter.releaseReservation();

  /// Launches the browser presentation for [checkoutUrl].
  ///
  /// Settles as soon as a return URI arrives at the configured return address,
  /// the customer dismisses the browser, the timeout elapses, or the launch
  /// fails — whichever happens first.
  ///
  /// Returns a [Future] completing with a [ZpCheckoutOutcome], which is always
  /// provisional. Confirm the payment on the merchant backend.
  ///
  /// Throws [ZpCheckoutAlreadyActiveException] if another checkout is active,
  /// [ZpCheckoutDisposedException] if this controller is disposed, or
  /// [ZpInvalidLaunchException] if [checkoutUrl] fails security checks.
  Future<ZpCheckoutOutcome> open({required Uri checkoutUrl}) async {
    if (_disposed) {
      _presenter.releaseReservation();
      throw const ZpCheckoutDisposedException();
    }
    if (_active != null) {
      _presenter.releaseReservation();
      throw const ZpCheckoutAlreadyActiveException();
    }

    try {
      _launchValidator.validate(checkoutUrl: checkoutUrl, configuration: configuration);
    } on ZpInvalidLaunchException catch (error) {
      _presenter.releaseReservation();
      _emit(ZpLaunchRejectedEvent(reason: error.message));
      rethrow;
    }

    final active = ActiveCheckout(
      onFinished: (outcome, duration, cause) {
        _active = null;
        unawaited(_presenter.dismissCheckout().catchError((Object _) => false));
        _emit(ZpFinishedEvent(outcome: outcome.outcomeName, duration: duration, cause: cause));
      },
    );
    _active = active;

    // Listen before launching: a return can arrive before openCheckout resolves.
    active.watch(
      _returnUriSource.uris.listen(
        handleReturnUri,
        onError: (Object error, StackTrace stackTrace) {
          active.finish(const ZpLaunchFailed(code: ZpLaunchFailureCode.platformError), cause: error);
        },
      ),
    );

    active.watch(
      _presenter.events.listen(
        (_) => active.finish(const ZpPresentationDismissed()),
        onError: (Object error, StackTrace stackTrace) {
          active.finish(const ZpLaunchFailed(code: ZpLaunchFailureCode.platformError), cause: error);
        },
      ),
    );

    active.expireAfter(configuration.timeout, const ZpTimedOut());

    _presentationInFlight = true;
    try {
      final launch = await _presenter.openCheckout(
        checkoutUrl,
        showTitle: configuration.showBrowserTitle,
        allowExternalBrowserFallback: configuration.allowExternalBrowserFallback,
      );
      _presentationInFlight = false;

      _emit(ZpPresentedEvent(checkoutHost: checkoutUrl.host, launched: launch.launched));

      if (_disposed) {
        // dispose() deferred settling this checkout to here rather than
        // finishing it (and cancelling its return-uri subscription) while
        // this was still pending — finish() is a no-op if a genuine return
        // already won the race in the meantime.
        active.finish(const ZpPresentationDismissed());
      } else if (!launch.launched) {
        active.finish(const ZpLaunchFailed(code: ZpLaunchFailureCode.rejectedByPlatform));
      }
    } on Object catch (error) {
      _presentationInFlight = false;
      active.finish(ZpLaunchFailed(code: mapLaunchFailureCode(error)), cause: error);
    }

    return active.outcome;
  }

  /// Processes an incoming return [uri] candidate against the active checkout.
  ///
  /// Ignores anything that arrives when no checkout is in flight, or after the
  /// current one has already settled.
  Future<void> handleReturnUri(Uri uri) async {
    final active = _active;
    if (active == null || active.isFinished) {
      return;
    }

    final normalized = _returnValidator.validate(
      candidate: uri,
      configuration: configuration,
      onRejectionObserved: (reason) => _emit(ZpReturnRejectedEvent(reason: reason)),
    );
    if (normalized == null) {
      return;
    }

    _emit(const ZpReturnAcceptedEvent());
    active.finish(ZpReturnReceived(returnUri: normalized));
  }

  /// Disposes this controller, settling any in-flight checkout as dismissed.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _presenter.releaseReservation();
    if (_presentationInFlight) {
      // openCheckout() hasn't resolved yet for the active checkout —
      // finishing now would cancel its return-uri subscription mid-flight
      // (dropping a return that might still land) and call
      // dismissCheckout() against a browser that isn't open yet. open()'s
      // own post-await code settles this correctly once openCheckout()
      // resolves.
      return;
    }
    _active?.finish(const ZpPresentationDismissed());
  }

  /// Hands [event] to the configured observer, if any.
  void _emit(ZpCheckoutEvent event) {
    final observer = configuration.observer;
    if (observer == null) {
      return;
    }
    try {
      observer.onEvent(event);
    } on Object {
      // Swallowed by design per ZpCheckoutObserver contract.
    }
  }
}
