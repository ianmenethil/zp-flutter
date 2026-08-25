/// Return URI source implementation backed by `package:app_links`.
///
/// Captures deep links, Android App Links, and iOS Universal Links received by
/// the Flutter application during checkout return redirection.
library;

import 'package:app_links/app_links.dart';
import 'package:meta/meta.dart';

import 'package:zenpay_flutter/src/return_handling/listen_for_return_contract.dart';

/// Adapter interface wrapping the [AppLinks] plugin for testability and isolation.
abstract interface class AppLinksPlatformAdapter {
  /// Fetches the initial deep link URI that launched the application, if present.
  Future<Uri?> getInitialLink();

  /// Stream emitting incoming deep link URIs while the app is running.
  Stream<Uri> get uriLinkStream;
}

/// Default implementation of [AppLinksPlatformAdapter] backed by `package:app_links`.
final class DefaultAppLinksAdapter implements AppLinksPlatformAdapter {
  /// Creates a [DefaultAppLinksAdapter].
  DefaultAppLinksAdapter({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get uriLinkStream => _appLinks.uriLinkStream;
}

/// [ZpReturnUriSource] implementation using `package:app_links` to capture App Links and Universal Links.
///
/// Combines the cold-start initial deep link (via [AppLinksPlatformAdapter.getInitialLink])
/// and the runtime stream of incoming links (via [AppLinksPlatformAdapter.uriLinkStream])
/// into a single unified stream of [uris].
final class AppLinksReturnUriSource implements ZpReturnUriSource {
  /// Creates an [AppLinksReturnUriSource] with either an [adapter] or [appLinks] instance.
  AppLinksReturnUriSource({AppLinksPlatformAdapter? adapter, AppLinks? appLinks})
    : assert(
        adapter == null || appLinks == null,
        'Supply either adapter or appLinks, not both — appLinks is ignored '
        'once adapter is set.',
      ),
      _adapter = adapter ?? DefaultAppLinksAdapter(appLinks: appLinks);

  final AppLinksPlatformAdapter _adapter;

  /// Whether some [AppLinksReturnUriSource] instance in this process has
  /// already consumed the cold-start initial link.
  ///
  /// `getInitialLink()` returns the same cached value on every call for the
  /// life of the process — the native side sets it once and never clears
  /// it — so this has to be a process-wide guard, not an instance field: a
  /// brand-new [AppLinksReturnUriSource] (as `createDefaultReturnUriSource()`
  /// builds per `ZpCheckout`) would otherwise still read and re-yield the
  /// same stale link a second, unrelated checkout attempt never actually
  /// received.
  static bool _initialLinkConsumed = false;

  /// Resets the one-shot guard above. Test-only — production code has no
  /// legitimate reason to re-consume a cold-start link already read once in
  /// this process.
  @visibleForTesting
  static void resetInitialLinkConsumedForTesting() {
    _initialLinkConsumed = false;
  }

  @override
  Stream<Uri> get uris async* {
    if (!_initialLinkConsumed) {
      _initialLinkConsumed = true;
      try {
        final initialUri = await _adapter.getInitialLink();
        if (initialUri != null) {
          yield initialUri;
        }
      } on Object {
        // Ignore initial link retrieval failures
      }
    }
    yield* _adapter.uriLinkStream;
  }
}

/// Creates the platform-default [ZpReturnUriSource] for Mobile.
ZpReturnUriSource createDefaultReturnUriSource() => AppLinksReturnUriSource();
