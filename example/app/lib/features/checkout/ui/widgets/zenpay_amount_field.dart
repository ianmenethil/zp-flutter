/// Payment amount field with currency affixes and quick-pick presets.
library;

import 'package:flutter/material.dart';

const _defaultCurrencyLabel = 'AUD';
const _fieldSectionTitle = 'PAYMENT AMOUNT';
const _currencySymbol = r'$';

/// A large `$<amount> AUD`-styled numeric field plus preset amount chips.
final class ZenPayAmountField extends StatelessWidget {
  /// Creates a [ZenPayAmountField].
  const ZenPayAmountField({
    required this.controller,
    required this.hintText,
    this.currencyLabel = _defaultCurrencyLabel,
    this.presets = const <int>[50, 100, 500, 1000],
    super.key,
  });

  /// Backing controller.
  final TextEditingController controller;

  /// Placeholder amount shown when [controller] is empty.
  final String hintText;

  /// Currency code shown after the amount, e.g. `'AUD'`.
  final String currencyLabel;

  /// Whole-dollar quick-pick amounts rendered as chips below the field.
  final List<int> presets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _fieldSectionTitle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: colorScheme.onSurfaceVariant),
          ),
          // stretch + IntrinsicHeight so the currency badge is exactly as tall
          // as the field beside it, whatever the text scale factor.
          IntrinsicHeight(
            child: Row(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(
                  child: Text(_currencySymbol, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(hintText: hintText, border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: colorScheme.error, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    currencyLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: colorScheme.onError),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row of Expanded, not Wrap: the presets must span the same width as
          // the field above them.
          Row(
            spacing: 8,
            children: presets
                .map(
                  (preset) => Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.text = '$preset',
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('\$$preset'),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
