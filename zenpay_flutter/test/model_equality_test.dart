/// Proves zenpay_flutter/CLAUDE.md's "Models should be immutable, overriding
/// == and hashCode" rule for the public outcome and configuration models.
///
/// `ZpCheckoutConfiguration.allowedCheckoutHosts` is a `Set<String>`, and
/// Dart's default `Set` equality is identity-based — a naive
/// `other.allowedCheckoutHosts == allowedCheckoutHosts` override would still
/// fail this test even after `==` is added. The fix needs element-wise set
/// comparison.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

void main() {
  group('ZpCheckoutOutcome equality', () {
    test('two ZpReturnReceived with the same returnUri are equal', () {
      final a = ZpReturnReceived(
        returnUri: Uri.parse('https://app.example.com/return?x=1'),
      );
      final b = ZpReturnReceived(
        returnUri: Uri.parse('https://app.example.com/return?x=1'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two ZpLaunchFailed with the same code are equal', () {
      const a = ZpLaunchFailed(code: ZpLaunchFailureCode.platformError);
      const b = ZpLaunchFailed(code: ZpLaunchFailureCode.platformError);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two ZpPresentationDismissed instances are equal', () {
      expect(const ZpPresentationDismissed(), equals(const ZpPresentationDismissed()));
    });
  });

  group('ZpCheckoutConfiguration equality', () {
    test('two configurations built from the same host set are equal', () {
      final a = ZpCheckoutConfiguration(
        allowedCheckoutHosts: const <String>{'checkout.example.com'},
        expectedReturnUri: Uri.parse('https://app.example.com/return'),
      );
      final b = ZpCheckoutConfiguration(
        allowedCheckoutHosts: const <String>{'checkout.example.com'},
        expectedReturnUri: Uri.parse('https://app.example.com/return'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
