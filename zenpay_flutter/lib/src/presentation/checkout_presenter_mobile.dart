/// Mobile presenter backed by `url_launcher`.
///
/// Presents Custom Tabs on Android and `SFSafariViewController` on iOS via
/// [LaunchMode.inAppBrowserView], falling back to the external system browser
/// ([LaunchMode.externalApplication]) when that surface cannot be launched and
/// the caller allows it.
///
/// `url_launcher` exposes no close/dismiss event for either surface — a
/// long-standing, still-open gap, not an oversight here: see
/// https://github.com/flutter/flutter/issues/20034 and
/// https://github.com/flutter/flutter/issues/57536 (Flutter feature requests
/// asking for exactly this) and https://issues.chromium.org/issues/332587540
/// (Chrome Custom Tabs itself ships no closure callback at the platform
/// level, so there is nothing for `url_launcher` to forward even if it
/// wanted to). [CheckoutPresenter.events] instead detects dismissal indirectly: resuming the
/// app while a checkout is presented starts a short grace period, so a
/// genuine return (which arrives separately, via the deep-link stream) can
/// still win the race; if nothing arrives before the grace period elapses,
/// the resume is treated as the user having backed out without completing
/// checkout. This mirrors the community-documented app-lifecycle workaround
/// at https://logickoder.medium.com/detecting-chrome-custom-tab-closure-in-android-a-coroutine-based-solution-ad3ee7b6204c
/// (code: https://gist.github.com/logickoder/564d4bc6ca77a4fdbed99957dd8eaf25),
/// minus that solution's native `ActivityManager` task-stack re-check —
/// this package ships no native platform code, and resume-plus-grace-period
/// alone is the same signal most `url_launcher`-based apps facing this gap
/// rely on.
/// [CheckoutPresenter.dismissCheckout] differs by platform: Android Custom Tabs has no
/// programmatic close at the OS level, but iOS's `SFSafariViewController`
/// genuinely supports `dismiss(animated:)`, which `url_launcher_ios` wires up
/// via `closeInAppWebView()`. Platform detection (rather than `url_launcher`'s
/// own `supportsCloseForLaunchMode`) is deliberate: that public function
/// delegates to `supportsMode` instead of the platform-interface's
/// `supportsCloseForMode`, so it falsely reports `true` for Android Custom
/// Tabs — verified against `url_launcher` 6.3.2 / `url_launcher_android`
/// 6.3.32 / `url_launcher_ios` 6.4.1 source.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:url_launcher/url_launcher.dart';

import 'package:zenpay_flutter/src/presentation/presenter.dart';

/// Creates the [CheckoutPresenter] for Android and iOS mobile platforms.
CheckoutPresenter createCheckoutPresenter() => _CheckoutPresenterMobile();

/// Presents ZenPay hosted checkout on mobile platforms via `url_launcher`.
final class _CheckoutPresenterMobile extends CheckoutPresenter with WidgetsBindingObserver {
  // ponytail: a fixed grace period, not configurable — matches the
  // community-documented workaround this mirrors (see class doc). Long
  // enough that a genuine return (checked independently, on the deep-link
  // stream) reliably wins the race; short enough not to noticeably delay
  // reporting a real dismissal.
  static const Duration _resumeGracePeriod = Duration(milliseconds: 500);

  final StreamController<void> _events = StreamController<void>.broadcast();

  bool _presenting = false;
  Timer? _graceTimer;

  @override
  Stream<void> get events => _events.stream;

  /// Launches [url] using [LaunchMode.inAppBrowserView].
  ///
  /// On Android, opens a Chrome Custom Tab. On iOS, presents `SFSafariViewController`.
  ///
  /// When that surface cannot be launched and [allowExternalBrowserFallback]
  /// is set, retries in the external system browser — the case that matters
  /// is an Android device with no Custom Tabs provider installed, which
  /// otherwise has no path through checkout at all. A device can report this
  /// either by returning `false` or by throwing, so both are treated as the
  /// same failure.
  ///
  /// The fallback never masks the original failure: if it does not launch
  /// either, the in-app error is rethrown with its stack trace intact so
  /// `mapLaunchFailureCode` still sees the platform's own error rather than a
  /// generic one.
  @override
  Future<PresentationLaunchResult> openCheckout(
    Uri url, {
    required bool showTitle,
    required bool allowExternalBrowserFallback,
  }) async {
    // Defensive reset: a prior launch that settled by timeout (rather than
    // through dismissCheckout) would otherwise leave the observer registered.
    _stopWatching();

    var launched = false;
    Object? inAppError;
    StackTrace? inAppStackTrace;

    try {
      launched = await launchUrl(
        url,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: BrowserConfiguration(showTitle: showTitle),
      );
    } on Object catch (error, stackTrace) {
      inAppError = error;
      inAppStackTrace = stackTrace;
    }

    if (launched) {
      _startWatching();
      return const PresentationLaunchResult(
        launched: true,
        usedExternalBrowserFallback: false,
      );
    }

    if (allowExternalBrowserFallback && await _launchExternal(url)) {
      _startWatching();
      return const PresentationLaunchResult(
        launched: true,
        usedExternalBrowserFallback: true,
      );
    }

    if (inAppError != null) {
      Error.throwWithStackTrace(inAppError, inAppStackTrace!);
    }

    return const PresentationLaunchResult(
      launched: false,
      usedExternalBrowserFallback: false,
    );
  }

  /// Opens [url] in the external system browser, reporting only whether it
  /// launched.
  ///
  /// A throw here is a failed fallback rather than a new error to surface —
  /// the caller either rethrows the original in-app failure or reports a
  /// plain unlaunched result.
  Future<bool> _launchExternal(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  /// Programmatically dismisses the in-app browser if supported by the host OS.
  ///
  /// Supported on iOS (`SFSafariViewController` via `closeInAppWebView`).
  /// Android Custom Tabs does not support programmatic closing from the hosting app.
  @override
  Future<bool> dismissCheckout() async {
    _stopWatching();

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      await closeInAppWebView();
      return true;
    } on Object {
      return false;
    }
  }

  /// Starts (or restarts) the resume-grace-period timer described in this
  /// library's doc comment — see there for why a bare resume isn't enough on
  /// its own. A pause/inactive transition within that window cancels it
  /// rather than letting it run out: the app didn't stay foregrounded, so
  /// the resume that started it wasn't a genuine return (e.g. the
  /// notification shade was pulled down while the tab was still open).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_presenting) {
      return;
    }
    if (state != AppLifecycleState.resumed) {
      _graceTimer?.cancel();
      _graceTimer = null;
      return;
    }
    _graceTimer?.cancel();
    _graceTimer = Timer(_resumeGracePeriod, () {
      if (!_presenting) {
        return;
      }
      _stopWatching();
      _events.add(null);
    });
  }

  void _startWatching() {
    _presenting = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void _stopWatching() {
    _graceTimer?.cancel();
    _graceTimer = null;
    if (_presenting) {
      _presenting = false;
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
