import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_embedded/zenpay_embedded.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final returnUriAddress = Uri.parse('https://payments.example.com/zenpay/app-return');

  group('EmbeddedCheckoutPresenter', () {
    test('openCheckout reports not launched when the navigator is unmounted', () async {
      final presenter = EmbeddedCheckoutPresenter(navigatorKey: GlobalKey<NavigatorState>(), returnUriAddress: returnUriAddress);

      final result = await presenter.openCheckout(
        Uri.parse('https://checkout.example.com/pay'),
        showTitle: true,
        allowExternalBrowserFallback: true,
      );

      expect(result.launched, isFalse);
      await presenter.dispose();
    });

    test('dismissCheckout returns false when no checkout is being presented', () async {
      final presenter = EmbeddedCheckoutPresenter(navigatorKey: GlobalKey<NavigatorState>(), returnUriAddress: returnUriAddress);

      expect(await presenter.dismissCheckout(), isFalse);
      await presenter.dispose();
    });

    test('exposes a returnUriSource usable as ZpReturnUriSource', () async {
      final presenter = EmbeddedCheckoutPresenter(navigatorKey: GlobalKey<NavigatorState>(), returnUriAddress: returnUriAddress);

      final captured = <Uri>[];
      final subscription = presenter.returnUriSource.uris.listen(captured.add);
      presenter.returnUriSource.addUri(returnUriAddress);
      await Future<void>.delayed(Duration.zero);

      expect(captured, <Uri>[returnUriAddress]);

      await subscription.cancel();
      await presenter.dispose();
    });
  });
}
