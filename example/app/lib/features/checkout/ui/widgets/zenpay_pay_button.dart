/// Pure presentational pay button — style only, no checkout logic.
///
/// Deliberately has no dependency on `zenpay_flutter`; it renders whatever
/// `onPressed`/`isBusy` it is handed. Launch orchestration lives in
/// `CheckoutPage._pay` (`../checkout_page.dart`).
library;

import 'package:flutter/material.dart';

const _defaultPayLabel = 'Pay with ZenPay';
const _defaultBusyLabel = 'Opening…';

/// A Material [FilledButton] with a busy/idle label swap.
///
/// Appearance comes entirely from the ambient [FilledButtonTheme] — this
/// widget exposes no colour, padding, or shape options.
final class ZenPayPayButton extends StatelessWidget {
  /// Creates a [ZenPayPayButton].
  const ZenPayPayButton({
    required this.onPressed,
    this.isBusy = false,
    this.label = _defaultPayLabel,
    this.busyLabel = _defaultBusyLabel,
    this.semanticLabel,
    super.key,
  });

  /// Called on tap. Pass `null` to render the button disabled.
  final VoidCallback? onPressed;

  /// Whether a launch is currently in flight.
  final bool isBusy;

  /// Label shown while idle.
  final String label;

  /// Label shown while busy.
  final String busyLabel;

  /// Overrides the label announced by assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      // The button is disabled while busy, so without a live region a
      // screen-reader user gets no confirmation their tap registered.
      liveRegion: isBusy,
      label: semanticLabel ?? (isBusy ? busyLabel : label),
      child: ExcludeSemantics(
        child: FilledButton(
          onPressed: onPressed,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isBusy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    key: const ValueKey('busy'),
                    children: <Widget>[
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(busyLabel),
                    ],
                  )
                : Text(label, key: const ValueKey('idle')),
          ),
        ),
      ),
    );
  }
}
