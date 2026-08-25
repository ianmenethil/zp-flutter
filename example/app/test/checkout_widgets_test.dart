/// Widget tests for the checkout UI widgets in
/// `lib/features/checkout/ui/widgets/`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_amount_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_environment_banner.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_labeled_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_pay_button.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_selectable_card.dart';

Future<void> _pump(WidgetTester tester, Widget widget) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
}

void main() {
  group('ZenPayAmountField', () {
    testWidgets('renders title, currency badge and presets', (tester) async {
      await _pump(tester, ZenPayAmountField(controller: TextEditingController(), hintText: '0.00'));

      expect(find.text('PAYMENT AMOUNT'), findsOneWidget);
      expect(find.text('AUD'), findsOneWidget);
      expect(find.text(r'$50'), findsOneWidget);
      expect(find.text(r'$100'), findsOneWidget);
      expect(find.text(r'$500'), findsOneWidget);
      expect(find.text(r'$1000'), findsOneWidget);
    });

    testWidgets('tapping a preset writes it into the controller', (tester) async {
      final controller = TextEditingController();
      await _pump(tester, ZenPayAmountField(controller: controller, hintText: '0.00'));

      await tester.tap(find.text(r'$100'));
      await tester.pump();

      expect(controller.text, '100');
    });

    testWidgets('renders a custom currency label', (tester) async {
      await _pump(tester, ZenPayAmountField(controller: TextEditingController(), hintText: '0.00', currencyLabel: 'USD'));

      expect(find.text('USD'), findsOneWidget);
      expect(find.text('AUD'), findsNothing);
    });
  });

  group('ZenPaySelectableCard', () {
    testWidgets('shows icon, label and subtitle', (tester) async {
      await _pump(
        tester,
        ZenPaySelectableCard(icon: Icons.credit_card, label: 'Make Payment', subtitle: 'Standard one-off transaction', selected: false, onTap: () {}),
      );

      expect(find.byIcon(Icons.credit_card), findsOneWidget);
      expect(find.text('Make Payment'), findsOneWidget);
      expect(find.text('Standard one-off transaction'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ZenPaySelectableCard(icon: Icons.credit_card, label: 'Make Payment', subtitle: 'Standard one-off transaction', selected: false, onTap: () => taps++),
      );

      await tester.tap(find.text('Make Payment'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('selected card draws the primary border', (tester) async {
      await _pump(
        tester,
        ZenPaySelectableCard(icon: Icons.credit_card, label: 'Make Payment', subtitle: 'Standard one-off transaction', selected: true, onTap: () {}),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final border = (container.decoration! as BoxDecoration).border! as Border;
      final primary = Theme.of(tester.element(find.byType(Container))).colorScheme.primary;

      expect(border.top.color, primary);
      expect(border.top.width, 2);
    });
  });

  group('ZenPayLabeledField', () {
    testWidgets('shows label and hint', (tester) async {
      await _pump(tester, ZenPayLabeledField(controller: TextEditingController(), label: 'Customer email', hintText: 'ada@example.com'));

      expect(find.text('Customer email'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('ZenPayPayButton', () {
    testWidgets('shows the idle label and fires onPressed', (tester) async {
      var taps = 0;
      await _pump(tester, ZenPayPayButton(onPressed: () => taps++));

      expect(find.text('Pay with ZenPay'), findsOneWidget);
      await tester.tap(find.text('Pay with ZenPay'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('swaps to the busy label while busy', (tester) async {
      await _pump(tester, const ZenPayPayButton(onPressed: null, isBusy: true));

      expect(find.text('Opening…'), findsOneWidget);
      expect(find.text('Pay with ZenPay'), findsNothing);
    });
  });

  group('ZenPayEnvironmentBanner', () {
    testWidgets('shows for sandbox hosts', (tester) async {
      await _pump(tester, const ZenPayEnvironmentBanner(allowedCheckoutHosts: <String>{'pay.sandbox.travelpay.com.au'}));

      expect(find.text('Sandbox environment — test payments only'), findsOneWidget);
    });

    testWidgets('hides for production hosts', (tester) async {
      await _pump(tester, const ZenPayEnvironmentBanner(allowedCheckoutHosts: <String>{'pay.travelpay.com.au'}));

      expect(find.text('Sandbox environment — test payments only'), findsNothing);
    });
  });
}
