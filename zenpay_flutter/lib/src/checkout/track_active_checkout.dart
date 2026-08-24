/// Local state for one in-flight checkout: the pending outcome, and everything
/// that must be cancelled once it settles.
library;

import 'dart:async';

import 'package:zenpay_flutter/src/models/checkout_results.dart';

/// Tracks one checkout launch. Used internally by `ZpCheckout`.
final class ActiveCheckout {
  /// Creates the state for a single checkout launch.
  ActiveCheckout({required this.onFinished});

  /// Called once, after the outcome settles and teardown has run.
  final void Function(
    ZpCheckoutOutcome outcome,
    Duration duration,
    Object? cause,
  )
  onFinished;

  final Completer<ZpCheckoutOutcome> _completer = Completer<ZpCheckoutOutcome>();
  final Stopwatch _elapsed = Stopwatch()..start();
  final List<StreamSubscription<void>> _subscriptions = <StreamSubscription<void>>[];
  Timer? _timeoutTimer;

  /// Resolves with the outcome of whichever source finished first.
  Future<ZpCheckoutOutcome> get outcome => _completer.future;

  /// Whether this checkout has already settled.
  bool get isFinished => _completer.isCompleted;

  /// Takes ownership of [subscription], cancelling it when this checkout ends.
  void watch(StreamSubscription<void> subscription) => _subscriptions.add(subscription);

  /// Settles with [onTimeout] if nothing else has after [timeout].
  void expireAfter(Duration timeout, ZpCheckoutOutcome onTimeout) {
    _timeoutTimer = Timer(timeout, () => finish(onTimeout));
  }

  /// Settles this checkout, then cancels the timer and every watched
  /// subscription. First call wins; later calls are no-ops, so a timeout firing
  /// just after a return arrived cannot double-complete.
  void finish(ZpCheckoutOutcome outcome, {Object? cause}) {
    if (_completer.isCompleted) {
      return;
    }
    _completer.complete(outcome);

    _timeoutTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();

    onFinished(outcome, _elapsed.elapsed, cause);
  }
}
