/// Test doubles and utilities for merchants integrating the ZenPay Checkout SDK.
///
/// Import this only from test files:
///
/// ```dart
/// import 'package:zenpay_flutter/testing.dart';
/// ```
///
/// This is a separate entrypoint from `package:zenpay_flutter/zenpay_checkout.dart`
/// so testing doubles (such as [FakeReturnUriSource]) are isolated and never bundled
/// or exposed in production code. It enables driving end-to-end checkout flows
/// (launch, link return, dismissal, and timeout) deterministically without requiring
/// a web browser, OS platform channels, or network connectivity.
///
/// ## Example Test Setup
///
/// ```dart
/// void main() {
///   test('completes with return outcome when return URI is emitted', () async {
///     final fakeSource = FakeReturnUriSource();
///     final checkout = ZpCheckout(
///       configuration: ZpCheckoutConfiguration(
///         allowedCheckoutHosts: {'checkout.example.com'},
///         expectedReturnUri: Uri.parse('https://app.example.com/return'),
///       ),
///       returnUriSource: fakeSource,
///     );
///
///     final outcomeFuture = checkout.open(
///       checkoutUrl: Uri.parse('https://checkout.example.com/pay?token=xyz'),
///     );
///
///     // Simulate return deep link from the browser:
///     fakeSource.emit(
///       Uri.parse('https://app.example.com/return?merchantUniquePaymentId=TWnwIUgR3vluPXcAphDWBg'),
///     );
///
///     expect(await outcomeFuture, isA<ZpReturnReceived>());
///     await fakeSource.close();
///   });
/// }
/// ```
library;

import 'dart:async';

import 'package:zenpay_flutter/src/return_handling/listen_for_return_contract.dart';

/// A [ZpReturnUriSource] driven by the test rather than by App Links.
///
/// Feed return URIs with [emit] to exercise a checkout without any platform
/// involvement. Always [close] it in `tearDown`.
final class FakeReturnUriSource implements ZpReturnUriSource {
  /// Creates a [FakeReturnUriSource] with an optional [initialUri].
  FakeReturnUriSource({this.initialUri});

  /// Replayed once, to the first subscriber only, mimicking
  /// `AppLinksReturnUriSource`'s one-shot cold-start-link behavior — a
  /// second, unrelated attempt against this same fake must not inherit it.
  final Uri? initialUri;

  /// The controller behind [uris]. Prefer [emit].
  final StreamController<Uri> controller = StreamController<Uri>.broadcast();

  bool _initialUriConsumed = false;

  @override
  Stream<Uri> get uris {
    if (initialUri != null && !_initialUriConsumed) {
      _initialUriConsumed = true;
      final replayed = StreamController<Uri>()..add(initialUri!);
      unawaited(replayed.addStream(controller.stream).whenComplete(replayed.close));
      return replayed.stream;
    }
    return controller.stream;
  }

  /// Delivers [uri] to the active checkout.
  void emit(Uri uri) => controller.add(uri);

  /// Releases the underlying controller.
  Future<void> close() async {
    await controller.close();
  }
}
