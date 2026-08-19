/// Smoke test for the checkout page UI shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenpay_example_app/main.dart';

void main() {
  testWidgets('renders the checkout page shell', (tester) async {
    await tester.pumpWidget(const ZenPayExampleApp());

    expect(find.text('ZenPay Hosted Checkout'), findsWidgets);

    // The results placeholder sits below the fold; scroll the list to reach it.
    await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
    await tester.pumpAndSettle();

    expect(find.text('No payment attempt yet.'), findsOneWidget);
  });
}
