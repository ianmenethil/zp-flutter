/// Persistent marker banner for non-production checkout environments.
///
/// Takes a raw host set rather than `ZpCheckoutConfiguration` — this
/// widget has no dependency on `zenpay_flutter`, matching the rest of
/// `widgets/` (style only, wired to the SDK later).
library;

import 'package:flutter/material.dart';

const _sandboxKeyword = 'sandbox';
const _uatKeyword = 'uat';
const _bannerText = 'Sandbox environment — test payments only';

/// Persistent marker for non-production checkout environments.
///
/// Renders an unmissable strip when every host in [allowedCheckoutHosts]
/// looks like a sandbox or UAT host, so shipping a test build to production
/// is visibly wrong rather than silently wrong. Renders [SizedBox.shrink]
/// otherwise, so leaving it in the tree costs nothing in production.
///
/// Colours come from the ambient [ThemeData.colorScheme]; nothing is
/// ZenPay-branded.
final class ZenPayEnvironmentBanner extends StatelessWidget {
  /// Creates a [ZenPayEnvironmentBanner] reading hosts from
  /// [allowedCheckoutHosts].
  const ZenPayEnvironmentBanner({required this.allowedCheckoutHosts, super.key});

  /// The checkout host allowlist deciding whether the banner shows.
  final Set<String> allowedCheckoutHosts;

  // ponytail: substring heuristic — production hosts never contain 'sandbox'
  // or 'uat' and the allowlist is tiny, so the false-positive surface is
  // negligible. Swap for an explicit environment field if a host ever
  // collides.
  bool get _isNonProduction => allowedCheckoutHosts.every((host) => host.contains(_sandboxKeyword) || host.contains(_uatKeyword));

  @override
  Widget build(BuildContext context) {
    if (!_isNonProduction) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(Icons.science_outlined, size: 18, color: colors.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _bannerText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onTertiaryContainer, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
