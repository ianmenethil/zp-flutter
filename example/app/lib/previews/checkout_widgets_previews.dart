/// Isolated widget previews for the checkout UI widgets.
///
/// These functions exist only for the Flutter Widget Previewer
/// (`flutter widget-preview start`); the app never calls them.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_amount_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_environment_banner.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_labeled_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_pay_button.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_selectable_card.dart';

/// Preview for [ZenPayAmountField] with AUD presets.
@Preview(
  name: 'AUD, 4 presets',
  group: 'ZenPayAmountField',
  size: Size(360, 260),
)
Widget zenpayAmountFieldPreview() {
  return ZenPayAmountField(
    controller: TextEditingController(text: '250.00'),
    hintText: '0.00',
  );
}

/// Preview for selected [ZenPaySelectableCard].
@Preview(name: 'Selected', group: 'ZenPaySelectableCard', size: Size(200, 120))
Widget zenpaySelectableCardSelectedPreview() {
  return ZenPaySelectableCard(
    icon: Icons.credit_card,
    label: 'Make Payment',
    subtitle: 'Standard one-off transaction',
    selected: true,
    onTap: () {},
  );
}

/// Preview for unselected [ZenPaySelectableCard].
@Preview(
  name: 'Unselected',
  group: 'ZenPaySelectableCard',
  size: Size(200, 120),
)
Widget zenpaySelectableCardUnselectedPreview() {
  return ZenPaySelectableCard(
    icon: Icons.lock_outline,
    label: 'Tokenise',
    subtitle: 'Save card details for later',
    selected: false,
    onTap: () {},
  );
}

/// Preview for [ZenPayLabeledField] with placeholder hint.
@Preview(name: 'With hint', group: 'ZenPayLabeledField', size: Size(320, 90))
Widget zenpayLabeledFieldPreview() {
  return ZenPayLabeledField(
    controller: TextEditingController(),
    label: 'Customer name',
    hintText: 'Ada Lovelace',
  );
}

/// Preview for idle [ZenPayPayButton].
@Preview(name: 'Idle', group: 'ZenPayPayButton', size: Size(320, 70))
Widget zenpayPayButtonIdlePreview() {
  return const ZenPayPayButton(onPressed: null);
}

/// Preview for busy [ZenPayPayButton].
@Preview(name: 'Busy', group: 'ZenPayPayButton', size: Size(320, 70))
Widget zenpayPayButtonBusyPreview() {
  return const ZenPayPayButton(onPressed: null, isBusy: true);
}

/// Preview for [ZenPayEnvironmentBanner] with sandbox hosts.
@Preview(
  name: 'Sandbox hosts',
  group: 'ZenPayEnvironmentBanner',
  size: Size(390, 60),
)
Widget zenpayEnvironmentBannerPreview() {
  return const ZenPayEnvironmentBanner(
    allowedCheckoutHosts: <String>{'pay.sandbox.travelpay.com.au'},
  );
}
