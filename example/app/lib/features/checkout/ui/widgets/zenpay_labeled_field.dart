/// Labeled outlined text field — style only; validation is the caller's job,
/// surfaced here purely as [ZenPayLabeledField.errorText].
library;

import 'package:flutter/material.dart';

/// An [OutlineInputBorder] [TextField] with an always-floating label.
final class ZenPayLabeledField extends StatelessWidget {
  /// Creates a [ZenPayLabeledField].
  const ZenPayLabeledField({
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.errorText,
    this.onChanged,
    super.key,
  });

  /// Backing controller.
  final TextEditingController controller;

  /// Field label, always shown above the input.
  final String label;

  /// Placeholder text shown when [controller] is empty.
  final String? hintText;

  /// Keyboard type, e.g. [TextInputType.emailAddress].
  final TextInputType? keyboardType;

  /// Keyboard action button, e.g. [TextInputAction.next].
  final TextInputAction? textInputAction;

  /// Validation message shown below the field, or `null` for none.
  final String? errorText;

  /// Called on every keystroke, e.g. to clear [errorText] once fixed.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hintText,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
