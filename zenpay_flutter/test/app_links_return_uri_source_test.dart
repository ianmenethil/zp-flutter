/// Tests for `app_links_return_uri_source.dart`'s `uris` stream: the merge of
/// the cold-start initial link with the runtime `uriLinkStream`, and the
/// catch-and-continue behavior when the initial-link lookup fails.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/src/return_handling/app_links_return_uri_source.dart';

/// Fake [AppLinksPlatformAdapter] whose initial-link result and runtime
/// stream are both controlled by the test.
final class _FakeAppLinksPlatformAdapter implements AppLinksPlatformAdapter {
  _FakeAppLinksPlatformAdapter({this.initialLink, this.initialLinkError});

  final Uri? initialLink;
  final Object? initialLinkError;
  final _streamController = StreamController<Uri>();

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
    test('yields the initial link before runtime stream events', () async {
      final adapter = _FakeAppLinksPlatformAdapter(initialLink: initialUri);
      final source = AppLinksReturnUriSource(adapter: adapter);

      final received = <Uri>[];
      final subscription = source.uris.listen(received.add);
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
      adapter.emit(runtimeUri);
      await Future<void>.delayed(Duration.zero);

      expect(received, [runtimeUri]);
      await subscription.cancel();
    });
  });
}
