/// Tests for the mobile presenter's external-browser fallback and its
/// resume-based dismissal detection (`checkout_presenter_mobile.dart`'s doc
/// comment explains why the latter exists — `url_launcher` gives Custom
/// Tabs / `SFSafariViewController` no closure event at all).
library;

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/src/presentation/presenter.dart';
import 'package:zenpay_flutter/src/presentation/checkout_presenter_mobile.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart' show LinkDelegate;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Records every launch mode requested and answers each with a queued result.
final class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _FakeUrlLauncher(this._answers);

  /// Result per call, in order. A [Object] entry is thrown instead of returned.
  final List<Object> _answers;

  /// Modes actually requested, in call order.
  final List<PreferredLaunchMode> requestedModes = <PreferredLaunchMode>[];

  /// Unused by these tests; required by [UrlLauncherPlatform].
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    requestedModes.add(options.mode);
    final answer = _answers[requestedModes.length - 1];
    if (answer is bool) {
      return answer;
    }
    throw answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Uri checkoutUrl = Uri.parse('https://checkout.example.com/pay');

  Future<PresentationLaunchResult> present(
    _FakeUrlLauncher launcher, {
    required bool allowExternalBrowserFallback,
  }) {
    UrlLauncherPlatform.instance = launcher;
    return createCheckoutPresenter().openCheckout(
      checkoutUrl,
      showTitle: true,
      allowExternalBrowserFallback: allowExternalBrowserFallback,
    );
  }

  group('external browser fallback', () {
    test('is not attempted when the in-app surface launches', () async {
      final launcher = _FakeUrlLauncher(<Object>[true]);

      final result = await present(
        launcher,
        allowExternalBrowserFallback: true,
      );

      expect(result.launched, isTrue);
      expect(result.usedExternalBrowserFallback, isFalse);
      expect(launcher.requestedModes, <PreferredLaunchMode>[
        PreferredLaunchMode.inAppBrowserView,
      ]);
    });

    test('retries externally when the in-app surface returns false', () async {
      final launcher = _FakeUrlLauncher(<Object>[false, true]);

      final result = await present(
        launcher,
        allowExternalBrowserFallback: true,
      );

      expect(result.launched, isTrue);
      expect(result.usedExternalBrowserFallback, isTrue);
      expect(launcher.requestedModes, <PreferredLaunchMode>[
        PreferredLaunchMode.inAppBrowserView,
        PreferredLaunchMode.externalApplication,
      ]);
    });

    test('retries externally when the in-app surface throws', () async {
      final launcher = _FakeUrlLauncher(<Object>[
        Exception('no provider'),
        true,
      ]);

      final result = await present(
        launcher,
        allowExternalBrowserFallback: true,
      );

      expect(result.launched, isTrue);
      expect(result.usedExternalBrowserFallback, isTrue);
    });

    test('is skipped entirely when the caller disallows it', () async {
      final launcher = _FakeUrlLauncher(<Object>[false]);

      final result = await present(
        launcher,
        allowExternalBrowserFallback: false,
      );

      expect(result.launched, isFalse);
      expect(result.usedExternalBrowserFallback, isFalse);
      expect(launcher.requestedModes, <PreferredLaunchMode>[
        PreferredLaunchMode.inAppBrowserView,
      ]);
    });

    test(
      'reports an unlaunched result when both surfaces return false',
      () async {
        final launcher = _FakeUrlLauncher(<Object>[false, false]);

        final result = await present(
          launcher,
          allowExternalBrowserFallback: true,
        );

        expect(result.launched, isFalse);
        expect(result.usedExternalBrowserFallback, isFalse);
      },
    );

    test('rethrows the in-app error when the fallback also fails', () async {
      final inAppError = Exception('in-app failed');
      final launcher = _FakeUrlLauncher(<Object>[
        inAppError,
        Exception('external failed too'),
      ]);

      await expectLater(
        present(launcher, allowExternalBrowserFallback: true),
        throwsA(same(inAppError)),
      );
    });
  });

  group('resume-based dismissal detection', () {
    // Comfortably longer than the presenter's internal grace period so a
    // real Timer in the production code has fired by the time a test reads
    // its result.
    const waitPastGracePeriod = Duration(milliseconds: 700);

    Future<CheckoutPresenter> presentAndKeepReference() async {
      UrlLauncherPlatform.instance = _FakeUrlLauncher(<Object>[true]);
      final presenter = createCheckoutPresenter();
      final result = await presenter.openCheckout(
        checkoutUrl,
        showTitle: true,
        allowExternalBrowserFallback: true,
      );
      expect(result.launched, isTrue);
      return presenter;
    }

    test(
      'emits once the app resumes and stays foregrounded past the grace period',
      () async {
        final presenter = await presentAndKeepReference();
        final events = <void>[];
        presenter.events.listen(events.add);

        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(waitPastGracePeriod);

        expect(events, hasLength(1));
      },
    );

    test('does not emit before the grace period elapses', () async {
      final presenter = await presentAndKeepReference();
      final events = <void>[];
      presenter.events.listen(events.add);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, isEmpty);
    });

    test('does not emit when a pause interrupts the grace period '
        '(e.g. the notification shade, tab still open)', () async {
      final presenter = await presentAndKeepReference();
      final events = <void>[];
      presenter.events.listen(events.add);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      await Future<void>.delayed(waitPastGracePeriod);

      expect(events, isEmpty);
    });

    test(
      'does not emit after dismissCheckout has already settled it',
      () async {
        final presenter = await presentAndKeepReference();
        final events = <void>[];
        presenter.events.listen(events.add);

        await presenter.dismissCheckout();
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await Future<void>.delayed(waitPastGracePeriod);

        expect(events, isEmpty);
      },
    );

    test('does not emit before any checkout has been presented', () async {
      final presenter = createCheckoutPresenter();
      final events = <void>[];
      presenter.events.listen(events.add);

      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(waitPastGracePeriod);

      expect(events, isEmpty);
    });
  });
}
