/// Configuration policies and settings for ZenPay Checkout operations.
///
/// Defines security constraints, host allowlists, expected return URIs,
/// session timeouts, UI options, and telemetry observers for [ZpCheckout].
library;

import 'package:meta/meta.dart';

import '../observability/checkout_event.dart';

const _httpsScheme = 'https';
const _errMissingHosts = 'At least one non-empty checkout host is required.';
const _errInvalidReturnUri =
    'The return URI must be a clean absolute HTTPS URI.';
const _errPositiveTimeout = 'Must be positive.';
const _errMinReturnUriLength = 'Must be at least 256.';
const _errMinReturnValueLength = 'Must be at least 16.';

/// Configuration policy for initializing and validating [ZpCheckout] operations.
///
/// Instances are immutable. Constructor assertions and validation checks ensure
/// that all security invariants (e.g. valid hostnames, clean HTTPS return URIs,
/// positive timeouts, and safe length bounds) are verified at instantiation time.
@immutable
final class ZpCheckoutConfiguration({
  required Set<String> allowedCheckoutHosts,

  /// The expected application HTTPS return broker URI.
  required final Uri expectedReturnUri,

  /// Maximum duration a checkout presentation can remain open before timing out.
  final Duration timeout = const Duration(minutes: 20),

  /// Whether to display the web browser toolbar title.
  ///
  /// May not be supported on all platforms — some in-app browser surfaces
  /// have no toolbar title to show. See the platform implementation
  /// package's README for what a given platform does with this option.
  final bool showBrowserTitle = true,

  /// Whether to allow external system browser fallback if the platform's
  /// in-app browser surface is unavailable.
  ///
  /// May not be supported on all platforms. See the platform implementation
  /// package's README for what a given platform does with this option.
  final bool allowExternalBrowserFallback = true,

  /// Maximum allowed byte/character length for incoming return URIs.
  final int maxReturnUriLength = 2048,

  /// Maximum allowed byte/character length for query parameters in return URIs.
  final int maxReturnValueLength = 512,

  /// Optional sink for structured SDK events.
  ///
  /// The SDK emits no logs or analytics of its own; supplying an observer is
  /// the only way to see inside a checkout. Most useful for the rejected-return
  /// case, which is otherwise entirely silent.
  final ZpCheckoutObserver? observer,
}) {
  /// The set of normalized HTTPS hostnames authorized for checkout URLs.
  final Set<String> allowedCheckoutHosts = Set<String>.unmodifiable(
    allowedCheckoutHosts.map((String host) => host.trim().toLowerCase()),
  );

  this {
    if (this.allowedCheckoutHosts.isEmpty ||
        this.allowedCheckoutHosts.any((String host) => host.isEmpty)) {
      throw ArgumentError.value(
        allowedCheckoutHosts,
        'allowedCheckoutHosts',
        _errMissingHosts,
      );
    }

    if (expectedReturnUri.scheme.toLowerCase() != _httpsScheme ||
        expectedReturnUri.host.isEmpty ||
        expectedReturnUri.userInfo.isNotEmpty ||
        expectedReturnUri.query.isNotEmpty ||
        expectedReturnUri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        expectedReturnUri,
        'expectedReturnUri',
        _errInvalidReturnUri,
      );
    }

    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', _errPositiveTimeout);
    }
    if (maxReturnUriLength < 256) {
      throw ArgumentError.value(
        maxReturnUriLength,
        'maxReturnUriLength',
        _errMinReturnUriLength,
      );
    }
    if (maxReturnValueLength < 16) {
      throw ArgumentError.value(
        maxReturnValueLength,
        'maxReturnValueLength',
        _errMinReturnValueLength,
      );
    }
  }
}
