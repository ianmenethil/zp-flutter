/// Tests for `checkout_telemetry.dart`'s observer factory and the
/// `ZpCheckoutEvent` hierarchy's equality/hashCode overrides.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

void main() {
  group('ZpCheckoutObserver.from', () {
    test('forwards each event to the callback in order', () {
      final received = <ZpCheckoutEvent>[];
      final observer = ZpCheckoutObserver.from(received.add);

      const a = ZpLaunchRejectedEvent(reason: 'bad host');
      const b = ZpReturnAcceptedEvent();
      observer
        ..onEvent(a)
        ..onEvent(b);

      expect(received, [a, b]);
    });
  });

  group('ZpLaunchRejectedEvent equality', () {
    test('equal for the same reason, unequal otherwise', () {
      const a = ZpLaunchRejectedEvent(reason: 'bad host');
      const b = ZpLaunchRejectedEvent(reason: 'bad host');
      const c = ZpLaunchRejectedEvent(reason: 'other');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('ZpPresentedEvent equality', () {
    test('equal for the same host and launched flag, unequal otherwise', () {
      const a = ZpPresentedEvent(checkoutHost: 'checkout.example.com', launched: true);
      const b = ZpPresentedEvent(checkoutHost: 'checkout.example.com', launched: true);
      const c = ZpPresentedEvent(checkoutHost: 'checkout.example.com', launched: false);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('ZpReturnRejectedEvent equality', () {
    test('equal for the same reason, unequal otherwise', () {
      const a = ZpReturnRejectedEvent(reason: ZpReturnRejectionReason.tooLong);
      const b = ZpReturnRejectedEvent(reason: ZpReturnRejectionReason.tooLong);
      const c = ZpReturnRejectedEvent(reason: ZpReturnRejectionReason.malformedQuery);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('ZpReturnAcceptedEvent equality', () {
    test('two instances are always equal', () {
      expect(const ZpReturnAcceptedEvent(), equals(const ZpReturnAcceptedEvent()));
    });
  });

  group('ZpFinishedEvent equality', () {
    test('equal when outcome, duration, and null cause match', () {
      const a = ZpFinishedEvent(outcome: 'returnReceived', duration: Duration(seconds: 1));
      const b = ZpFinishedEvent(outcome: 'returnReceived', duration: Duration(seconds: 1));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equal when a non-null cause also matches', () {
      final cause = Exception('boom');
      final a = ZpFinishedEvent(outcome: 'launchFailed', duration: const Duration(seconds: 2), cause: cause);
      final b = ZpFinishedEvent(outcome: 'launchFailed', duration: const Duration(seconds: 2), cause: cause);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('unequal when outcome, duration, or cause differ', () {
      const base = ZpFinishedEvent(outcome: 'returnReceived', duration: Duration(seconds: 1));

      expect(base, isNot(equals(const ZpFinishedEvent(outcome: 'timedOut', duration: Duration(seconds: 1)))));
      expect(base, isNot(equals(const ZpFinishedEvent(outcome: 'returnReceived', duration: Duration(seconds: 2)))));
      expect(base, isNot(equals(ZpFinishedEvent(outcome: 'returnReceived', duration: const Duration(seconds: 1), cause: Exception('x')))));
    });
  });
}
