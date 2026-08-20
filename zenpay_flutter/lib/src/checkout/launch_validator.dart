/// Security validation for checkout launch parameters and URLs.
///
/// Ensures checkout URLs meet strict security and syntax rules prior to
/// browser presentation.
library;

import 'package:zenpay_flutter/src/configuration/checkout_configuration.dart';
import 'package:zenpay_flutter/src/exceptions/checkout_event.dart';

/// Predefined error messages for launch validation failures.
abstract final class _ValidationMessage {
  /// Error message when the checkout URL fails security or host-allowlist checks.
  static const checkoutUrlNotAllowed = 'Checkout URL is not allowed.';
}

/// Whether [url] is a secure checkout URL allowed by [configuration].
///
/// Validates that [url] satisfies all the following security requirements:
/// - Scheme is strictly `https` (case-insensitive).
/// - Contains no embedded user credentials ([Uri.userInfo] is empty).
/// - Contains no URI fragment ([Uri.fragment] is empty).
/// - Uses default HTTPS port `443` ([Uri.port] is `443`).
/// - Total URL string representation does not exceed 4096 characters.
/// - Host matches one of the normalized hostnames configured in
///   [ZpCheckoutConfiguration.allowedCheckoutHosts].
///
/// This predicate is exported at the library level so that external presentation
/// surfaces (such as web frame components) can enforce the exact same host and
/// scheme policy without duplicating validation logic.
bool isAllowedCheckoutUrl(Uri url, ZpCheckoutConfiguration configuration) =>
    url.scheme.toLowerCase() == 'https' &&
    url.userInfo.isEmpty &&
    url.fragment.isEmpty &&
    url.port == 443 &&
    url.toString().length <= 4096 &&
    configuration.allowedCheckoutHosts.contains(url.host.toLowerCase());

/// Validates checkout launch parameters prior to initiating browser presentation.
///
/// Checks target checkout URLs against security policies and allowlisted
/// domains.
final class ZpLaunchValidator {
  /// Creates a [ZpLaunchValidator].
  const ZpLaunchValidator();

  /// Validates [checkoutUrl] against [configuration].
  ///
  /// Throws [ZpInvalidLaunchException] if [checkoutUrl] does not satisfy
  /// [isAllowedCheckoutUrl].
  void validate({
    required Uri checkoutUrl,
    required ZpCheckoutConfiguration configuration,
  }) {
    if (!isAllowedCheckoutUrl(checkoutUrl, configuration)) {
      throw const ZpInvalidLaunchException(
        _ValidationMessage.checkoutUrlNotAllowed,
      );
    }
  }
}
