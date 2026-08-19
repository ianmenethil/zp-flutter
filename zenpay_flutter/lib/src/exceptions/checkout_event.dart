/// Exceptions thrown during ZenPay Checkout operations.
///
/// Provides a sealed hierarchy of exception types representing validation,
/// state, and lifecycle errors encountered by the SDK.
library;

import '../checkout/checkout_controller.dart';

/// Base sealed class for exceptions thrown by the ZenPay Checkout SDK.
///
/// All custom errors emitted synchronously or asynchronously by [ZpCheckout]
/// inherit from this class, allowing callers to catch them using a single type.
sealed class const ZpCheckoutException(
  /// A message describing the error condition.
  final String message,
) implements Exception {
  @override
  String toString() => '$runtimeType: $message';
}

const _errAlreadyActiveMessage = 'A ZenPay checkout is already active.';
const _errDisposedMessage = 'The ZenPay checkout controller is disposed.';

/// Thrown when attempting to launch a checkout while another checkout is already in progress.
///
/// [ZpCheckout] only permits a single active presentation at a time. Callers
/// must await the completion of an active session (or dispose the controller)
/// before calling [ZpCheckout.open] again.
final class ZpCheckoutAlreadyActiveException extends ZpCheckoutException {
  // Left in old style: Cannot express a constant super-constructor argument in a parameterless primary constructor.
  const ZpCheckoutAlreadyActiveException() : super(_errAlreadyActiveMessage);
}

/// Thrown when invoking methods on a disposed [ZpCheckout] instance.
///
/// After [ZpCheckout.dispose] has been called, the controller cannot be
/// reused to launch subsequent checkout sessions.
final class ZpCheckoutDisposedException extends ZpCheckoutException {
  // Left in old style: Cannot express a constant super-constructor argument in a parameterless primary constructor.
  const ZpCheckoutDisposedException() : super(_errDisposedMessage);
}

/// Thrown when parameters given to [ZpCheckout.open] fail security checks.
///
/// This occurs when:
/// - The checkout URL host is not listed in [ZpCheckoutConfiguration.allowedCheckoutHosts].
/// - The checkout URL scheme is not HTTPS, port is not 443, contains credentials/fragment,
///   or exceeds 4096 characters in length.
final class const ZpInvalidLaunchException(super.message)
    extends ZpCheckoutException;
