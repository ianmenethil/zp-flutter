/// Checkout mode selectors for the sample UI.
///
/// - [TransactionMode] — ZenPay session `mode` (0–3) plus UI label/icon.
///
/// There is no presentation-mode selector: the SDK presents checkout in a
/// system browser surface only (Custom Tabs on Android,
/// `SFSafariViewController` on iOS, a new tab on web), so there is nothing
/// to choose between.
library;

import 'package:flutter/material.dart';

/// ZenPay `/v2/sessions` mode; [wireValue] is what the API expects.
enum TransactionMode {
  /// Standard one-off payment (ZenPay mode 0).
  makePayment(
    0,
    'Make Payment',
    'Standard one-off transaction',
    Icons.credit_card,
  ),

  /// Store card details for later use, no charge (ZenPay mode 1).
  tokenise(1, 'Tokenise', 'Securely store card details', Icons.key),

  /// One-off payment with a customer-editable amount (ZenPay mode 2).
  customPayment(2, 'Custom Payment', 'Customer-editable amount', Icons.bolt),

  /// Hold funds for later capture (ZenPay mode 3).
  preauthorization(3, 'Pre-Auth', 'Hold funds for later capture', Icons.lock);

  const TransactionMode(this.wireValue, this.label, this.subtitle, this.icon);

  /// ZenPay session `mode` sent to the API.
  final int wireValue;

  /// UI label for this mode.
  final String label;

  /// UI subtitle describing this mode.
  final String subtitle;

  /// Icon shown alongside [label].
  final IconData icon;

  /// Whether this mode takes an amount at all — every mode but Tokenise.
  bool get usesAmount => this != tokenise;

  /// Whole-dollar quick-pick presets shown below the amount field. Purely a
  /// UI convenience — the backend accepts any positive amount.
  List<int> get amountPresets => const <int>[50, 100, 500, 1000];
}
