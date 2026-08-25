/// Tests for `checkout_results.dart`'s `outcomeName` and the inequality
/// cases `model_equality_test.dart` doesn't already cover.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

void main() {
  group('outcomeName', () {
    test('is stable per outcome type', () {
      expect(ZpReturnReceived(returnUri: Uri.parse('https://a.example/r')).outcomeName, 'returnReceived');
      expect(const ZpPresentationDismissed().outcomeName, 'presentationDismissed');
      expect(const ZpTimedOut().outcomeName, 'timedOut');
      expect(const ZpLaunchFailed(code: ZpLaunchFailureCode.platformError).outcomeName, 'launchFailed');
    });
  });

  group('ZpTimedOut equality', () {
    test('two instances are always equal', () {
      expect(const ZpTimedOut(), equals(const ZpTimedOut()));
      expect(const ZpTimedOut().hashCode, equals(const ZpTimedOut().hashCode));
    });
  });

  group('inequality', () {
    test('ZpReturnReceived differs by returnUri', () {
      final a = ZpReturnReceived(returnUri: Uri.parse('https://a.example/r?x=1'));
      final b = ZpReturnReceived(returnUri: Uri.parse('https://a.example/r?x=2'));
      expect(a, isNot(equals(b)));
    });

    test('ZpLaunchFailed differs by code', () {
      const a = ZpLaunchFailed(code: ZpLaunchFailureCode.platformError);
      const b = ZpLaunchFailed(code: ZpLaunchFailureCode.rejectedByPlatform);
      expect(a, isNot(equals(b)));
    });

    test('different outcome types are never equal', () {
      expect(const ZpPresentationDismissed(), isNot(equals(const ZpTimedOut())));
    });
  });
}
