/// Validation and security sanitization for checkout return deep links.
///
/// Ensures incoming return URIs arrive at the expected return address, parse
/// cleanly, and respect length limits.
///
/// This says nothing about where a return came from. Any app or page able to
/// open the return address can produce a URI that passes here, so an accepted
/// return is provisional: it means the browser came back, not that a payment
/// happened. Establishing that is the merchant backend's job.
library;

import 'package:zenpay_flutter/src/configuration/checkout_settings.dart';
import 'package:zenpay_flutter/src/observability/checkout_telemetry.dart';

/// Delimiters used when parsing return URI queries.
abstract final class _QueryParam {
  /// Delimiter separating query parameter key-value pairs (`&`).
  static const pairSeparator = '&';

  /// Delimiter separating a parameter key from its value (`=`).
  static const keyValueSeparator = '=';
}

/// Whether [candidate]'s scheme, host, port, and path exactly match
/// [expected], and it carries no embedded credentials or fragment.
///
/// Shared by [ZpReturnValidator.validate] (checking the URI actually
/// delivered by the OS/browser against the configured return address on
/// every incoming return) and `matchesReturnAddress` in
/// `web_return_validation.dart` (the web popup's own same-origin check) —
/// kept as one predicate so the two can't drift apart.
bool matchesReturnUriAddress(Uri candidate, Uri expected) {
  return candidate.scheme.toLowerCase() == expected.scheme.toLowerCase() &&
      candidate.host.toLowerCase() == expected.host.toLowerCase() &&
      candidate.port == expected.port &&
      candidate.path == expected.path &&
      candidate.userInfo.isEmpty &&
      candidate.fragment.isEmpty;
}

/// Validates and normalizes candidate return URIs against the expected return policy.
final class ZpReturnValidator {
  /// Creates a [ZpReturnValidator].
  const ZpReturnValidator();

  /// Validates a [candidate] return URI against [configuration] security rules.
  ///
  /// Returns a normalized, sanitized [Uri] if validation succeeds, or `null` if
  /// validation fails. The query is preserved, re-encoded canonically, for the
  /// application to read; its contents are not inspected here.
  ///
  /// [onRejectionObserved], when supplied, is called with the reason immediately before `null` is returned.
  /// It is observational only and cannot affect the result.
  Uri? validate({
    required Uri candidate,
    required ZpCheckoutConfiguration configuration,
    void Function(ZpReturnRejectionReason reason)? onRejectionObserved,
  }) {
    if (candidate.toString().length > configuration.maxReturnUriLength) {
      onRejectionObserved?.call(ZpReturnRejectionReason.tooLong);
      return null;
    }

    final expected = configuration.expectedReturnUri;
    if (!matchesReturnUriAddress(candidate, expected)) {
      onRejectionObserved?.call(ZpReturnRejectionReason.addressMismatch);
      return null;
    }

    if (candidate.query.isEmpty) {
      onRejectionObserved?.call(ZpReturnRejectionReason.emptyQuery);
      return null;
    }

    final parsed = _parseQuery(candidate.query);
    if (parsed == null) {
      onRejectionObserved?.call(ZpReturnRejectionReason.malformedQuery);
      return null;
    }

    for (final value in parsed.values) {
      if (value.length > configuration.maxReturnValueLength) {
        onRejectionObserved?.call(ZpReturnRejectionReason.valueTooLong);
        return null;
      }
    }

    return expected.replace(queryParameters: parsed);
  }

  Map<String, String>? _parseQuery(String query) {
    final result = <String, String>{};
    try {
      for (final pair in query.split(_QueryParam.pairSeparator)) {
        if (pair.isEmpty) {
          return null;
        }

        final separator = pair.indexOf(_QueryParam.keyValueSeparator);
        final encodedKey = separator == -1 ? pair : pair.substring(0, separator);
        final encodedValue = separator == -1 ? '' : pair.substring(separator + 1);
        final key = Uri.decodeQueryComponent(encodedKey);
        final value = Uri.decodeQueryComponent(encodedValue);

        if (result.containsKey(key)) {
          return null;
        }
        result[key] = value;
      }
    } on FormatException {
      return null;
    }

    return result;
  }
}
