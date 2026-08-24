import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/testing.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

final class _FakeCheckoutPresenter extends CheckoutPresenter {
  final StreamController<void> _events = StreamController<void>.broadcast();
  bool launched = true;

  @override
  Stream<void> get events => _events.stream;

  @override
  Future<PresentationLaunchResult> openCheckout(
    Uri url, {
    required bool showTitle,
    required bool allowExternalBrowserFallback,
  }) async => PresentationLaunchResult(
    launched: launched,
    usedExternalBrowserFallback: false,
  );

  @override
  Future<bool> dismissCheckout() async => true;

  void dismiss() => _events.add(null);
}

/// A presenter whose [openCheckout] hangs until the test completes
/// [openCompleter] — for reproducing a `dispose()` that races an in-flight
/// `open()` before the browser has actually opened.
final class _HangingCheckoutPresenter extends CheckoutPresenter {
  final _events = StreamController<void>.broadcast();
  final Completer<PresentationLaunchResult> openCompleter = Completer<PresentationLaunchResult>();
  int dismissCallCount = 0;

  @override
  Stream<void> get events => _events.stream;

  @override
  Future<PresentationLaunchResult> openCheckout(
    Uri url, {
    required bool showTitle,
    required bool allowExternalBrowserFallback,
  }) => openCompleter.future;

  @override
  Future<bool> dismissCheckout() async {
    dismissCallCount++;
    return true;
  }
}

void main() {
  group('mapLaunchFailureCode', () {
    test('MissingPluginException maps to platformUnavailable', () {
      expect(
        mapLaunchFailureCode(MissingPluginException()),
        ZpLaunchFailureCode.platformUnavailable,
      );
    });

    test('any other error maps to platformError', () {
      expect(
        mapLaunchFailureCode(Exception('boom')),
        ZpLaunchFailureCode.platformError,
      );
    });
  });

  group('ZpCheckout', () {
    late ZpCheckoutConfiguration configuration;
    late FakeReturnUriSource returnUriSource;
    late _FakeCheckoutPresenter presenter;
    late ZpCheckout checkout;

    setUp(() {
      configuration = ZpCheckoutConfiguration(
        allowedCheckoutHosts: const <String>{'checkout.example.com'},
        expectedReturnUri: Uri.parse('https://app.example.com/return'),
      );
      returnUriSource = FakeReturnUriSource();
      presenter = _FakeCheckoutPresenter();
      checkout = ZpCheckout(
        configuration: configuration,
        returnUriSource: returnUriSource,
        presenter: presenter,
      );
    });

    tearDown(() async {
      await checkout.dispose();
      await returnUriSource.close();
    });

    test('a valid return URI completes with ZpReturnReceived', () async {
      final outcome = checkout.open(
        checkoutUrl: Uri.parse(
          'https://checkout.example.com/pay?secureToken=abc',
        ),
      );

      returnUriSource.emit(
        Uri.parse(
          'https://app.example.com/return?merchantUniquePaymentId=order-1',
        ),
      );

      expect(await outcome, isA<ZpReturnReceived>());
    });

    test('an empty-query match on the return address is ignored, not accepted '
        'as a return', () async {
      var completed = false;
      final outcome = checkout.open(
        checkoutUrl: Uri.parse(
          'https://checkout.example.com/pay?secureToken=abc',
        ),
      );
      unawaited(outcome.then((_) => completed = true));

      returnUriSource.emit(Uri.parse('https://app.example.com/return'));
      await pumpEventQueue();
      expect(completed, isFalse);

      returnUriSource.emit(
        Uri.parse(
          'https://app.example.com/return?merchantUniquePaymentId=order-1',
        ),
      );

      expect(await outcome, isA<ZpReturnReceived>());
    });

    test(
      'a presenter dismissal event completes with ZpPresentationDismissed',
      () async {
        final outcome = checkout.open(
          checkoutUrl: Uri.parse(
            'https://checkout.example.com/pay?secureToken=abc',
          ),
        );

        presenter.dismiss();

        expect(await outcome, isA<ZpPresentationDismissed>());
      },
    );

    test('a disallowed checkout host throws ZpInvalidLaunchException', () {
      expect(
        () => checkout.open(
          checkoutUrl: Uri.parse('https://not-allowed.example.com/pay'),
        ),
        throwsA(isA<ZpInvalidLaunchException>()),
      );
    });

    // Proves review finding #1 end-to-end: the SDK's own documented pattern
    // is one ZpCheckout, open() called again per attempt (see
    // example/app/.../checkout_page.dart). A stale cold-start return must
    // not be replayed into an unrelated later attempt.
    test(
      'a stale initial return is not replayed into a second, unrelated open() call',
      () async {
        final sourceWithInitial = FakeReturnUriSource(
          initialUri: Uri.parse(
            'https://app.example.com/return?merchantUniquePaymentId=order-A',
          ),
        );
        final localCheckout = ZpCheckout(
          configuration: configuration,
          returnUriSource: sourceWithInitial,
          presenter: presenter,
        );

        final firstOutcome = await localCheckout.open(
          checkoutUrl: Uri.parse('https://checkout.example.com/pay?secureToken=a'),
        );
        expect(firstOutcome, isA<ZpReturnReceived>());
        expect(
          (firstOutcome as ZpReturnReceived).returnUri.queryParameters['merchantUniquePaymentId'],
          'order-A',
        );

        final secondOutcomeFuture = localCheckout.open(
          checkoutUrl: Uri.parse('https://checkout.example.com/pay?secureToken=b'),
        );
        await pumpEventQueue();

        // Only payment B's own return should ever resolve this attempt.
        sourceWithInitial.emit(
          Uri.parse(
            'https://app.example.com/return?merchantUniquePaymentId=order-B',
          ),
        );
        final secondOutcome = await secondOutcomeFuture;

        expect(secondOutcome, isA<ZpReturnReceived>());
        expect(
          (secondOutcome as ZpReturnReceived).returnUri.queryParameters['merchantUniquePaymentId'],
          'order-B',
        );
        await sourceWithInitial.close();
      },
    );

    // Proves review finding #2: dispose() settles the internal completer and
    // fires dismissCheckout() synchronously, before openCheckout() has even
    // resolved. A genuine return delivered in that window must not be
    // silently dropped in favor of a false ZpPresentationDismissed outcome.
    test(
      'dispose() while openCheckout() is still pending does not drop a return that arrives before openCheckout() resolves',
      () async {
        final hangingPresenter = _HangingCheckoutPresenter();
        final source = FakeReturnUriSource();
        final localCheckout = ZpCheckout(
          configuration: configuration,
          returnUriSource: source,
          presenter: hangingPresenter,
        );

        final outcomeFuture = localCheckout.open(
          checkoutUrl: Uri.parse('https://checkout.example.com/pay?secureToken=abc'),
        );

        // openCheckout() is still pending — no browser has actually opened,
        // so dismissCheckout() must not fire yet.
        await localCheckout.dispose();
        expect(hangingPresenter.dismissCallCount, 0);

        var resolved = false;
        unawaited(outcomeFuture.then((_) => resolved = true));
        await pumpEventQueue();
        expect(
          resolved,
          isFalse,
          reason:
              "the caller's open() future must not resolve until "
              'openCheckout() itself resolves',
        );

        // A genuine return arrives while openCheckout() is still pending —
        // the return-uri subscription must still be alive to catch it.
        source.emit(
          Uri.parse(
            'https://app.example.com/return?merchantUniquePaymentId=order-1',
          ),
        );
        await pumpEventQueue();
        expect(hangingPresenter.dismissCallCount, 1);

        hangingPresenter.openCompleter.complete(
          const PresentationLaunchResult(
            launched: true,
            usedExternalBrowserFallback: false,
          ),
        );

        final outcome = await outcomeFuture;
        expect(outcome, isA<ZpReturnReceived>());
        await source.close();
      },
    );
  });
}
