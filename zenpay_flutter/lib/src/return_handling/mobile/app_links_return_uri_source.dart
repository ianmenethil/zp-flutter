/// Return URI source implementation backed by `package:app_links`.
///
/// Captures deep links, Android App Links, and iOS Universal Links received by
/// the Flutter application during checkout return redirection.
library;

import 'package:app_links/app_links.dart';

import 'package:zenpay_flutter/src/return_handling/return_uri_source.dart';

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
  AppLinksReturnUriSource({
    AppLinksPlatformAdapter? adapter,
    AppLinks? appLinks,
  }) : assert(
         adapter == null || appLinks == null,
         'Supply either adapter or appLinks, not both — appLinks is ignored '
         'once adapter is set.',
       ),
       _adapter = adapter ?? DefaultAppLinksAdapter(appLinks: appLinks);

  final AppLinksPlatformAdapter _adapter;

  @override
  Stream<Uri> get uris async* {
    try {
      final initialUri = await _adapter.getInitialLink();
      if (initialUri != null) {
        yield initialUri;
      }
    } on Object {
      // Ignore initial link retrieval failures
    }
    yield* _adapter.uriLinkStream;
  }
}

/// Creates the platform-default [ZpReturnUriSource] for Mobile.
ZpReturnUriSource createDefaultReturnUriSource() => AppLinksReturnUriSource();
