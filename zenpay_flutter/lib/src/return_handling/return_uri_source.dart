/// Stream abstraction for receiving application return URIs.
///
/// Decouples link ingestion (App Links, Universal Links, testing fakes) from
/// the checkout controller and return validation logic.
library;

/// Interface for capturing incoming application return URIs (e.g., via App Links or Universal Links).
///
/// Implementations deliver a stream of [Uri] events representing deep links
/// routed to the host application while a checkout is pending.
abstract interface class ZpReturnUriSource {
  /// Stream emitting incoming deep link/return URIs directed to this app.
  ///
  /// Should replay any initial launch deep link (for cold starts) and emit
  /// all subsequent deep links received while running.
  Stream<Uri> get uris;
}
