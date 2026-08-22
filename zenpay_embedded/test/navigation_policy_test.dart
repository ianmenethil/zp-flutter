import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Imported by path, not through the package barrel: the policy is internal.
import 'package:zenpay_embedded/src/navigation_policy.dart';

void main() {
  final returnUriAddress = Uri.parse('https://payments.example.com/zenpay/app-return');

  /// Runs the policy and reports both the decision and anything it captured.
  ({NavigationDecision decision, List<Uri> captured}) decide(String url) {
    final captured = <Uri>[];
    final decision = decideNavigation(url, returnUriAddress: returnUriAddress, onReturnUri: captured.add);
    return (decision: decision, captured: captured);
  }

  group('decideNavigation', () {
    test('allows the hosted checkout page and any https 3DS hop', () {
      for (final url in <String>[
        'https://pay.sandbox.example.com/checkout?secureToken=abc',
        // An issuer ACS host cannot be enumerated in advance, so https is the
        // only rule that can apply to it.
        'https://acs.some-unknown-issuer.example/3ds/challenge',
      ]) {
        final result = decide(url);
        expect(result.decision, NavigationDecision.navigate, reason: url);
        expect(result.captured, isEmpty, reason: url);
      }
    });

    test('blocks every scheme other than https', () {
      for (final url in <String>[
        'http://pay.sandbox.example.com/checkout',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'data:text/html,<script>1</script>',
        'zenpay://return',
      ]) {
        expect(decide(url).decision, NavigationDecision.prevent, reason: url);
      }
    });

    test('allows about:blank so the widget can clear the card form', () {
      expect(decide(blankPage).decision, NavigationDecision.navigate);
    });

    test('captures the return redirect and does not follow it', () {
      final url = '$returnUriAddress?merchantUniquePaymentId=PAY-1001&state=state_secret_123';
      final result = decide(url);

      expect(result.decision, NavigationDecision.prevent);
      expect(result.captured.single, Uri.parse(url));
    });

    test('does not treat a look-alike return address as the return', () {
      for (final url in <String>[
        // Different host.
        'https://payments.example.com.evil.test/zenpay/app-return?merchantUniquePaymentId=1',
        // Different path.
        'https://payments.example.com/zenpay/app-return-x?merchantUniquePaymentId=1',
      ]) {
        expect(decide(url).captured, isEmpty, reason: url);
      }
    });

    test('blocks a URL it cannot parse', () {
      expect(decide('https://[').decision, NavigationDecision.prevent);
    });
  });
}
