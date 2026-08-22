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
  });
}
