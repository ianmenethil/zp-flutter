/// Configuration policies and settings for ZenPay Checkout operations.
///
/// Defines security constraints, host allowlists, expected return URIs,
/// session timeouts, UI options, and telemetry observers for [ZpCheckout].
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:zenpay_flutter/src/checkout/run_checkout_flow.dart' show ZpCheckout;
import 'package:zenpay_flutter/src/observability/checkout_telemetry.dart';

const _httpsScheme = 'https';
const _errMissingHosts = 'At least one non-empty checkout host is required.';
const _errInvalidReturnUri = 'The return URI must be a clean absolute HTTPS URI.';
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
  /// Creates a validated [ZpCheckoutConfiguration].
  this {
    if (this.allowedCheckoutHosts.isEmpty || this.allowedCheckoutHosts.any((host) => host.isEmpty)) {
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

  /// The set of normalized HTTPS hostnames authorized for checkout URLs.
  final Set<String> allowedCheckoutHosts = Set<String>.unmodifiable(
    allowedCheckoutHosts.map((host) => host.trim().toLowerCase()),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZpCheckoutConfiguration &&
          _setEquality.equals(other.allowedCheckoutHosts, allowedCheckoutHosts) &&
          other.expectedReturnUri == expectedReturnUri &&
          other.timeout == timeout &&
          other.showBrowserTitle == showBrowserTitle &&
          other.allowExternalBrowserFallback == allowExternalBrowserFallback &&
          other.maxReturnUriLength == maxReturnUriLength &&
          other.maxReturnValueLength == maxReturnValueLength &&
          other.observer == observer);

  @override
  int get hashCode => Object.hash(
    ZpCheckoutConfiguration,
    _setEquality.hash(allowedCheckoutHosts),
    expectedReturnUri,
    timeout,
    showBrowserTitle,
    allowExternalBrowserFallback,
    maxReturnUriLength,
    maxReturnValueLength,
    observer,
  );
}

/// Dart's default `Set` equality is identity, not element-wise — this is what
/// makes `allowedCheckoutHosts` comparable by value in `==`/`hashCode` above.
const _setEquality = SetEquality<String>();
