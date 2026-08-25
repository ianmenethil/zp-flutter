/// Tests for `open_checkout_contract.dart`'s `PresentationLaunchResult`
/// equality and `CheckoutPresenter`'s default no-op `reserveLaunch`/
/// `releaseReservation` implementations.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

/// Minimal presenter that overrides only what's abstract, to exercise the
/// base class's default `reserveLaunch`/`releaseReservation`.
final class _MinimalPresenter extends CheckoutPresenter {
  @override
  Stream<void> get events => const Stream<void>.empty();

  @override
  Future<PresentationLaunchResult> openCheckout(Uri url, {required bool showTitle, required bool allowExternalBrowserFallback}) async =>
      const PresentationLaunchResult(launched: true, usedExternalBrowserFallback: false);

  @override
  Future<bool> dismissCheckout() async => true;
}

void main() {
  group('PresentationLaunchResult equality', () {
    test('equal for the same fields, unequal otherwise', () {
      const a = PresentationLaunchResult(launched: true, usedExternalBrowserFallback: false);
      const b = PresentationLaunchResult(launched: true, usedExternalBrowserFallback: false);
      const c = PresentationLaunchResult(launched: false, usedExternalBrowserFallback: false);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('CheckoutPresenter default reservation behavior', () {
    test('reserveLaunch defaults to true and releaseReservation is a no-op', () {
      final presenter = _MinimalPresenter();

      expect(presenter.reserveLaunch(), isTrue);
      expect(presenter.releaseReservation, returnsNormally);
    });
  });
}
