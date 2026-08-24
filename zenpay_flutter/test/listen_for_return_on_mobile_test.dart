/// Tests for `app_links_return_uri_source.dart`'s `uris` stream: the merge of
/// the cold-start initial link with the runtime `uriLinkStream`, and the
/// catch-and-continue behavior when the initial-link lookup fails.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/src/return_handling/mobile/listen_for_return_on_mobile.dart';

/// Fake [AppLinksPlatformAdapter] whose initial-link result and runtime
/// stream are both controlled by the test.
final class _FakeAppLinksPlatformAdapter implements AppLinksPlatformAdapter {
  _FakeAppLinksPlatformAdapter({this.initialLink, this.initialLinkError});

  final Uri? initialLink;
  final Exception? initialLinkError;
  // Matches package:app_links' real uriLinkStream, which is broadcast —
  // it must support being listened to across multiple checkout attempts
  // over the app's lifetime, not just once.
  final _streamController = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async {
    if (initialLinkError != null) throw initialLinkError!;
    return initialLink;
  }

  @override
  Stream<Uri> get uriLinkStream => _streamController.stream;

  /// Pushes a runtime deep link, as `package:app_links` would on an incoming link.
  void emit(Uri uri) => _streamController.add(uri);
}

void main() {
  final initialUri = Uri.parse('https://app.example.com/return?t=initial');
  final runtimeUri = Uri.parse('https://app.example.com/return?t=runtime');

  group('AppLinksReturnUriSource.uris', () {
    // The one-shot guard is process-wide (static), not per-instance — reset
    // it before each test so tests don't leak state into one another. The
    // two replay tests below deliberately do NOT reset between their two
    // `.listen()` calls, since that's the exact process-wide persistence
    // they're proving.
    setUp(AppLinksReturnUriSource.resetInitialLinkConsumedForTesting);

    test('yields the initial link before runtime stream events', () async {
      final adapter = _FakeAppLinksPlatformAdapter(initialLink: initialUri);
      final source = AppLinksReturnUriSource(adapter: adapter);

      final received = <Uri>[];
      final subscription = source.uris.listen(received.add);
      // uriLinkStream is broadcast, so an emit before the generator has
      // actually subscribed to it (after its own await on getInitialLink())
      // would be silently dropped, unlike a single-subscription stream.
      await pumpEventQueue();
      adapter.emit(runtimeUri);
      await Future<void>.delayed(Duration.zero);

      expect(received, [initialUri, runtimeUri]);
      await subscription.cancel();
    });

    test(
      'yields only runtime stream events when there is no initial link',
      () async {
        final adapter = _FakeAppLinksPlatformAdapter();
        final source = AppLinksReturnUriSource(adapter: adapter);

        final received = <Uri>[];
        final subscription = source.uris.listen(received.add);
        await pumpEventQueue();
        adapter.emit(runtimeUri);
        await Future<void>.delayed(Duration.zero);

        expect(received, [runtimeUri]);
        await subscription.cancel();
      },
    );

    test('swallows an initial-link lookup failure and still yields the runtime stream', () async {
      final adapter = _FakeAppLinksPlatformAdapter(
        initialLinkError: Exception('platform channel error'),
      );
      final source = AppLinksReturnUriSource(adapter: adapter);

      final received = <Uri>[];
      final subscription = source.uris.listen(received.add);
      await pumpEventQueue();
      adapter.emit(runtimeUri);
      await Future<void>.delayed(Duration.zero);

      expect(received, [runtimeUri]);
      await subscription.cancel();
    });

    // Proves the stale-cold-start-link-replay bug (review finding #1): the
    // native `getInitialLink()` result is cached process-wide by the OS and
    // returned unconditionally on every call, but `uris` is a getter whose
    // `async*` body re-runs — and re-fetches/re-yields that cached value —
    // on every new subscription. A checkout attempt started after an earlier
    // one has already consumed the cold-start link must not see it again.
    test(
      'a stale initial link is not replayed to a second subscription on the same source',
      () async {
        final adapter = _FakeAppLinksPlatformAdapter(initialLink: initialUri);
        final source = AppLinksReturnUriSource(adapter: adapter);

        final firstReceived = <Uri>[];
        final firstSubscription = source.uris.listen(firstReceived.add);
        await pumpEventQueue();
        await firstSubscription.cancel();

        final secondReceived = <Uri>[];
        final secondSubscription = source.uris.listen(secondReceived.add);
        await pumpEventQueue();
        adapter.emit(runtimeUri);
        await Future<void>.delayed(Duration.zero);

        expect(firstReceived, [initialUri]);
        expect(secondReceived, [runtimeUri]);
        await secondSubscription.cancel();
      },
    );

    // The harder case: `createDefaultReturnUriSource()` builds a brand-new
    // `AppLinksReturnUriSource` per call, so a per-instance guard alone is
    // insufficient — the stale value lives in the native adapter shared
    // across instances (the OS's own process-wide cache), exactly as this
    // fake reuses one adapter across two independently-constructed sources.
    test(
      'a stale initial link is not replayed to a second, independently-constructed source sharing the same native adapter',
      () async {
        final adapter = _FakeAppLinksPlatformAdapter(initialLink: initialUri);

        final firstSource = AppLinksReturnUriSource(adapter: adapter);
        final firstReceived = <Uri>[];
        final firstSubscription = firstSource.uris.listen(firstReceived.add);
        await pumpEventQueue();
        await firstSubscription.cancel();

        final secondSource = AppLinksReturnUriSource(adapter: adapter);
        final secondReceived = <Uri>[];
        final secondSubscription = secondSource.uris.listen(secondReceived.add);
        await pumpEventQueue();
        adapter.emit(runtimeUri);
        await Future<void>.delayed(Duration.zero);

        expect(firstReceived, [initialUri]);
        expect(secondReceived, [runtimeUri]);
        await secondSubscription.cancel();
      },
    );
  });
}
