/// Selectable bordered option card — the visual template behind the
/// transaction-mode picker (`TransactionMode`, `checkout_modes.dart`).
library;

import 'package:flutter/material.dart';

/// A bordered, tappable card showing an icon and label on one row, a subtitle
/// beneath, and a highlighted border when [selected].
final class ZenPaySelectableCard extends StatelessWidget {
  /// Creates a [ZenPaySelectableCard].
  const ZenPaySelectableCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Icon shown beside the label.
  final IconData icon;

  /// Primary option label.
  final String label;

  /// Secondary description shown under [label].
  final String subtitle;

  /// Whether this option is the current selection.
  final bool selected;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              spacing: 8,
              children: <Widget>[
                Icon(icon, color: colorScheme.primary),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
