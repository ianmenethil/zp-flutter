/// Integration test for the checkout page's mode/amount/customer flow.
///
/// UI-only by design: no network calls and no SDK launch, so it runs anywhere
/// the app renders. The pay step's browser launch cannot be driven in-test,
/// which is why this stops at the form.
///
/// Run on web with:
///   flutter test integration_test -d chrome
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_labeled_field.dart';
import 'package:zenpay_example_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mode toggle, amount entry and customer input work end to end', (
    tester,
  ) async {
    await tester.pumpWidget(const ZenPayExampleApp());
    await tester.pumpAndSettle();

    // TextFields embed their own Scrollables too, so scrolling needs a
    // finder resolving to exactly one match — `.first` picks the
    // outermost Scrollable (the page's own ListView), found before any
    // TextField-internal ones in tree order.
    final list = find.byType(Scrollable).first;

    // The amount field renders in Make Payment mode (the default),
    // restricted to the backend's fixed-amount presets.
    await tester.scrollUntilVisible(
      find.text('PAYMENT AMOUNT'),
      200,
      scrollable: list,
    );
    expect(find.text('PAYMENT AMOUNT'), findsOneWidget);

    // Tapping a preset chip doesn't throw or change the transaction mode.
    await tester.tap(find.text(r'$50'));
    await tester.pump();
    expect(find.text('Make Payment'), findsOneWidget);

    // Tokenise shows no amount field at all.
    await tester.scrollUntilVisible(
      find.text('Tokenise'),
      -200,
      scrollable: list,
    );
    await tester.tap(find.text('Tokenise'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Transaction mode:'),
      -200,
      scrollable: list,
    );
    expect(find.text('PAYMENT AMOUNT'), findsNothing);

    // Custom Payment keeps the free-typed amount field too.
    await tester.tap(find.text('Custom Payment'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PAYMENT AMOUNT'),
      200,
      scrollable: list,
    );
    expect(find.text('PAYMENT AMOUNT'), findsOneWidget);

    // Back to Make Payment for the customer-field leg.
    await tester.scrollUntilVisible(
      find.text('Transaction mode:'),
      -200,
      scrollable: list,
    );
    await tester.tap(find.text('Make Payment'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PAYMENT AMOUNT'),
      200,
      scrollable: list,
    );
    expect(find.text('PAYMENT AMOUNT'), findsOneWidget);

    // Customer fields accept input.
    final nameField = find.descendant(
      of: find.widgetWithText(ZenPayLabeledField, 'Customer name'),
      matching: find.byType(TextField),
    );
    await tester.scrollUntilVisible(nameField, 200, scrollable: list);
    await tester.enterText(nameField, 'Ada Lovelace');
    expect(find.text('Ada Lovelace'), findsOneWidget);

    // The results placeholder sits below the fold.
    await tester.scrollUntilVisible(
      find.text('No payment attempt yet.'),
      200,
      scrollable: list,
    );
    expect(find.text('No payment attempt yet.'), findsOneWidget);
  });
}
