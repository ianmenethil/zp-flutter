/// Web presenter: presents the hosted checkout page in a new browser tab.
///
/// The web platform has no equivalent of Android Custom Tabs or
/// `SFSafariViewController` — the application already runs inside a browser —
/// so a separate tab is the closest analogue that keeps the Flutter
/// application alive and the [CheckoutPresenter] contract intact.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:zenpay_flutter/src/presentation/presenter.dart';

/// Creates the [CheckoutPresenter] for the web platform.
CheckoutPresenter createCheckoutPresenter() => _CheckoutPresenterWeb();

/// Handle to a browser window opened by `window.open`.
extension type _BrowserWindow(JSObject _) implements JSObject {
  /// Closes the window.
  external void close();

  /// Whether the window has been closed, by this code or by the user.
  external bool get closed;

  /// The window's location object.
  external _Location get location;
}

/// Handle to a browser window location object.
extension type _Location(JSObject _) implements JSObject {
  /// The URL of the current window location.
  external String get href;
  external set href(String value);
}

/// Opens [url] in the browser target named [target], sized per [features].
///
/// Returns `null` when the browser refuses the request, which in practice means
/// a popup blocker rejected it.
@JS('window.open')
external _BrowserWindow? _windowOpen(
  String url,
  String target,
  String features,
);

/// Window features for [_windowOpen].
///
/// Empty: a non-empty `features` string (e.g. explicit `width`/`height`) is what
/// tells a browser to open a reduced-chrome popup window instead of a normal tab.
/// Leaving this empty opens a standard browser tab with full chrome and address bar intact.
const String _popupFeatures = '';
const String _blankTarget = '_blank';

/// Presents ZenPay hosted checkout in a new browser tab.
///
/// Two behaviours differ from the mobile presenter and are inherent to the
/// platform rather than provisional:
///
/// * `window.open` only succeeds while the browser still considers itself inside
///   a user gesture. [reserveLaunch] opens a blank popup synchronously, inside
///   the tap that starts a launch — before `createSession` or any other
///   `await` gets a chance to end that gesture — and [openCheckout] navigates
///   that already-open window instead of calling `window.open` again. A
///   caller that skips [reserveLaunch] (or receives `false` from it) still
///   goes through [openCheckout]'s own direct `window.open` call, which can
///   be blocked the same way it always could.
/// * The opened window is not given `noopener`, because the specification requires
///   `window.open` to return `null` when it is set, leaving no handle to detect
///   closure or to honour [dismissCheckout]. The destination is always a host the
///   SDK has already validated against the configured checkout allowlist.
final class _CheckoutPresenterWeb extends CheckoutPresenter {
  // ponytail: polling is the only way to observe a cross-tab close — there is no
  // close event for a window you opened. 500ms costs nothing next to a payment
  // and bounds the dismissal delay; drop it if that ever needs to be tighter.
  static const Duration _closePollInterval = Duration(milliseconds: 500);

  final StreamController<void> _events = StreamController<void>.broadcast();

  _BrowserWindow? _active;
  _BrowserWindow? _reserved;
  Timer? _closeWatchdog;

  @override
  Stream<void> get events => _events.stream;

  /// Opens a blank popup synchronously, before the caller does anything
  /// asynchronous, so the browser's user-gesture window is still open when
  /// [openCheckout] later navigates it — even after an `await` (such as a
  /// checkout launch request) that would otherwise have let the gesture
  /// expire and the popup get blocked.
  ///
  /// Any reservation left over from a launch that never called
  /// [openCheckout] or [releaseReservation] is closed first, so a launcher
  /// bug can't leak popups.
  @override
  bool reserveLaunch() {
    _reserved?.close();
    final opened = _windowOpen('', _blankTarget, _popupFeatures);
    _reserved = opened;
    return opened != null;
  }

  /// Closes a popup opened by [reserveLaunch] without presenting anything in
  /// it — call when the work between reservation and [openCheckout] failed.
  @override
  void releaseReservation() {
    _reserved?.close();
    _reserved = null;
  }

  /// Presents [url] in a new browser tab: navigates the window
  /// [reserveLaunch] already opened, or — for a caller that didn't reserve —
  /// opens one directly the same way this method always has.
  ///
  /// [showTitle] and [allowExternalBrowserFallback] are accepted to satisfy
  /// [CheckoutPresenter] and are deliberately unused: neither has a web
  /// meaning. `showTitle` configures an Android Custom Tab toolbar that does
  /// not exist here, and `allowExternalBrowserFallback` describes falling
  /// back from an in-app surface to the system browser — on web the tab
  /// already *is* the system browser, so there is nothing to fall back from.
  @override
  Future<PresentationLaunchResult> openCheckout(
    Uri url, {
    required bool showTitle,
    required bool allowExternalBrowserFallback,
  }) async {
    _stopWatching();

    final reserved = _reserved;
    _reserved = null;
    final opened = reserved ?? _windowOpen(url.toString(), _blankTarget, _popupFeatures);

    if (opened == null) {
      return const PresentationLaunchResult(
        launched: false,
        usedExternalBrowserFallback: false,
      );
    }
    if (reserved != null) {
      reserved.location.href = url.toString();
    }

    _active = opened;

    _closeWatchdog = Timer.periodic(_closePollInterval, (timer) {
      if (!opened.closed) {
        return;
      }
      _stopWatching();
      _events.add(null);
    });

    // A new tab is the normal presentation on web, not a degraded
    // fallback from an in-app surface, so this is never reported as an
    // external fallback.
    return const PresentationLaunchResult(
      launched: true,
      usedExternalBrowserFallback: false,
    );
  }

  @override
  Future<bool> dismissCheckout() async {
    final active = _active;
    if (active == null || active.closed) {
      _stopWatching();
      return false;
    }

    active.close();
    _stopWatching();
    _events.add(null);
    return true;
  }

  void _stopWatching() {
    _closeWatchdog?.cancel();
    _closeWatchdog = null;
    _active = null;
  }
}
