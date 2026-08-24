/// Structured telemetry emitted as a checkout progresses.
library;

import 'package:meta/meta.dart';

/// Receives [ZpCheckoutEvent]s as the SDK works.
///
/// Implement this to forward SDK activity into your own logging or analytics.
/// The SDK writes nothing anywhere itself.
///
/// [onEvent] is called synchronously on the SDK's own code path. Keep it cheap
/// and non-blocking, and do not call back into the SDK from it. Any exception
/// thrown from [onEvent] is caught and discarded, so observing a checkout can
/// never change its outcome.
abstract interface class ZpCheckoutObserver {
  /// Creates a [ZpCheckoutObserver] from an [onEvent] callback function.
  factory ZpCheckoutObserver.from(
    void Function(ZpCheckoutEvent event) onEvent,
  ) = _CallbackCheckoutObserver;

  /// Called once per event, in the order the events occur.
  void onEvent(ZpCheckoutEvent event);
}

final class _CallbackCheckoutObserver implements ZpCheckoutObserver {
  const _CallbackCheckoutObserver(this._onEvent);

  final void Function(ZpCheckoutEvent event) _onEvent;

  @override
  void onEvent(ZpCheckoutEvent event) => _onEvent(event);
}

/// Why a candidate return URI was refused.
enum ZpReturnRejectionReason {
  /// The URI was longer than `ZpCheckoutConfiguration.maxReturnUriLength`.
  tooLong,

  /// Scheme, host, port or path did not match the configured return address,
  /// or the URI carried credentials or a fragment.
  addressMismatch,

  /// The query could not be parsed, or repeated a key.
  malformedQuery,

  /// The candidate matched the expected return address but carried no query
  /// — an address hit alone carries no return data, so it is not accepted
  /// as a real return.
  emptyQuery,

  /// A query value was longer than
  /// `ZpCheckoutConfiguration.maxReturnValueLength`.
  valueTooLong,
}

/// A single point in a checkout's lifecycle.
///
/// Delivered to a [ZpCheckoutObserver] in process. Events carry no full
/// checkout URL and no raw return query, so the credentials in a checkout URL
/// cannot reach a log sink through one.
@immutable
sealed class ZpCheckoutEvent {
  /// Base constructor for checkout events.
  const ZpCheckoutEvent();
}

/// A launch failed validation and no browser was opened.
final class ZpLaunchRejectedEvent extends ZpCheckoutEvent {
  /// Creates a [ZpLaunchRejectedEvent] with the given rejection [reason].
  const ZpLaunchRejectedEvent({
    required this.reason,
  });

  /// A short, non-sensitive description of the failed precondition.
  final String reason;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ZpLaunchRejectedEvent && other.reason == reason);

  @override
  int get hashCode => Object.hash(ZpLaunchRejectedEvent, reason);
}

/// The browser presentation was requested for a validated launch.
final class ZpPresentedEvent extends ZpCheckoutEvent {
  /// Creates a [ZpPresentedEvent] with the [checkoutHost] and launch status.
  const ZpPresentedEvent({
    required this.checkoutHost,
    required this.launched,
  });

  /// The checkout host, which the merchant already allowlisted. Never the full
  /// URL, which carries the credentials.
  final String checkoutHost;

  /// Whether the platform reported a successful launch.
  final bool launched;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ZpPresentedEvent && other.checkoutHost == checkoutHost && other.launched == launched);

  @override
  int get hashCode => Object.hash(ZpPresentedEvent, checkoutHost, launched);
}

/// A candidate return URI was refused. The checkout remains active.
final class ZpReturnRejectedEvent extends ZpCheckoutEvent {
  /// Creates a [ZpReturnRejectedEvent] with the rejection [reason].
  const ZpReturnRejectedEvent({
    required this.reason,
  });

  /// Why the URI was refused. The URI itself is never included.
  final ZpReturnRejectionReason reason;

  @override
  bool operator ==(Object other) => identical(this, other) || (other is ZpReturnRejectedEvent && other.reason == reason);

  @override
  int get hashCode => Object.hash(ZpReturnRejectedEvent, reason);
}

/// A valid return URI was accepted and the checkout is completing.
final class ZpReturnAcceptedEvent extends ZpCheckoutEvent {
  /// Creates a [ZpReturnAcceptedEvent].
  const ZpReturnAcceptedEvent();

  @override
  bool operator ==(Object other) => other is ZpReturnAcceptedEvent;

  @override
  int get hashCode => (ZpReturnAcceptedEvent).hashCode;
}

/// The checkout finished, for any reason.
final class ZpFinishedEvent extends ZpCheckoutEvent {
  /// Creates a [ZpFinishedEvent] with the outcome, duration, and optional cause.
  const ZpFinishedEvent({
    required this.outcome,
    required this.duration,
    this.cause,
  });

  /// The stable outcome name, for example `returnReceived`. See
  /// `ZpCheckoutOutcome.outcomeName`.
  final String outcome;

  /// How long the attempt was active.
  final Duration duration;

  /// The raw error behind a `ZpLaunchFailed` outcome, when one was captured.
  /// `null` for every other outcome.
  ///
  /// Diagnostic only. This is an arbitrary platform-thrown [Object], so inspect
  /// it before forwarding it anywhere.
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ZpFinishedEvent && other.outcome == outcome && other.duration == duration && other.cause == cause);

  @override
  int get hashCode => Object.hash(ZpFinishedEvent, outcome, duration, cause);
}
