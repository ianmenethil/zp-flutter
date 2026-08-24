/// Red/green regression tests for the two testable defects in
/// `findings-dart.md` (#1 `merchantCode` path splicing, #2 non-finite
/// `paymentAmount`).
///
/// These assert the DESIRED behaviour, so they are expected to FAIL against
/// the current implementation — that failure is the proof the defects are
/// real. Each becomes green once the corresponding fix lands; neither test
/// needs changing to get there.
///
/// The control tests in each group pass both before and after, which is what
/// shows the assertions themselves are sound rather than merely strict.
library;

import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';

const _endpoint = 'https://pay.sandbox.b2bpay.com.au/Online/v5';

/// A 32-byte secret, the minimum `_keyBytes` accepts.
const _secret = 'zenpay-test-hmac-secret-32-bytes';

ZpCheckoutOptions _optionsWith(String merchantCode) => ZpCheckoutOptions(
  url: _endpoint,
  merchantCode: merchantCode,
  apiKey: 'api-key-value',
  fingerprint: 'f'.padLeft(128, 'f'),
  merchantUniquePaymentId: const ZpMupid('mupid-0001'),
  timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
  customerEmail: 'jane@example.com',
  paymentAmount: '49.90',
  customerName: 'Jane Smith',
  customerReference: 'ORD-1001',
  redirectUrl: 'https://merchant.example/return',
);

ZpCallbackUrlTokenPayload _payloadWith(Object? paymentAmount) => ZpCallbackUrlTokenPayload(
  mode: ZpPluginMode.makePayment,
  merchantUniquePaymentId: const ZpMupid('mupid-0001'),
  timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
  paymentAmount: paymentAmount,
);

void main() {
  // Finding #1 — the invariant, deliberately not a charset policy.
  //
  // `createZpCheckoutUrl` splices `merchantCode` into the URL path, where a
  // literal `/` is a segment separator and `..` is removed by RFC 3986
  // dot-segment normalisation. Asserting a specific allowed charset would be
  // inventing an arbitrary rule, so instead this asserts the contract that
  // must hold whatever charset is chosen:
  //
  //   the call either fails validation, or merchantCode occupies exactly one
  //   path segment between the base path and `Authorise`
  //
  // A merchantCode that is silently reinterpreted into a different path
  // satisfies neither branch.
  group('createZpCheckoutUrl merchantCode path invariant', () {
    void expectPathInvariant(String merchantCode) {
      final result = createZpCheckoutUrl(_optionsWith(merchantCode));

      if (result case ZpUrlFailure()) {
        return; // Rejecting the input is an acceptable outcome.
      }

      final success = result as ZpUrlSuccess;

      // Compare SEGMENTS, not the joined path string. Building the expected
      // string by interpolating merchantCode the same way the implementation
      // does would make a slash-bearing code match itself, hiding exactly the
      // defect under test. As a segment list, merchantCode must occupy
      // exactly one segment.
      expect(
        Uri.parse(success.url).pathSegments,
        <String>[
          ...Uri.parse(_endpoint).pathSegments,
          merchantCode,
          'Authorise',
        ],
        reason:
            'merchantCode "$merchantCode" was accepted but did not occupy '
            'exactly one path segment between the base path and Authorise — '
            'it was silently reinterpreted rather than rejected',
      );
    }

    test('control: a plain alphanumeric merchantCode round-trips', () {
      expectPathInvariant('ZenTest1');
    });

    test('a merchantCode containing a slash does not add a path segment', () {
      expectPathInvariant('Zen/Test');
    });

    test('a merchantCode of ".." does not consume the version segment', () {
      expectPathInvariant('..');
    });

    test('a merchantCode of "../.." does not consume the base path', () {
      expectPathInvariant('../..');
    });

    test('a merchantCode of "../../etc" does not replace the base path', () {
      expectPathInvariant('../../etc');
    });

    test('a trailing slash does not produce an empty path segment', () {
      expectPathInvariant('ZenTrailing/');
    });
  });

  // Finding #2 — non-finite paymentAmount.
  //
  // `createZpCallbackUrlToken`'s own dartdoc promises `ArgumentError` for a
  // malformed payload. The Dart guard `_isAmountShaped` only checks `is
  // num`, so NaN/Infinity pass validation and blow up later inside
  // `jsonEncode` as `JsonUnsupportedObjectError` — a type the documented
  // contract never mentions and a caller catching `ArgumentError` will not
  // handle.
  group('createZpCallbackUrlToken rejects non-finite paymentAmount', () {
    test('control: a finite num is accepted', () {
      expect(
        createZpCallbackUrlToken(_payloadWith(49.9), _secret),
        isNotEmpty,
      );
    });

    test('control: a String amount is accepted', () {
      expect(
        createZpCallbackUrlToken(_payloadWith('49.90'), _secret),
        isNotEmpty,
      );
    });

    test('control: a null amount is accepted', () {
      expect(
        createZpCallbackUrlToken(_payloadWith(null), _secret),
        isNotEmpty,
      );
    });

    test('NaN throws ArgumentError', () {
      expect(
        () => createZpCallbackUrlToken(_payloadWith(double.nan), _secret),
        throwsArgumentError,
      );
    });

    test('Infinity throws ArgumentError', () {
      expect(
        () => createZpCallbackUrlToken(_payloadWith(double.infinity), _secret),
        throwsArgumentError,
      );
    });

    test('negative Infinity throws ArgumentError', () {
      expect(
        () => createZpCallbackUrlToken(
          _payloadWith(double.negativeInfinity),
          _secret,
        ),
        throwsArgumentError,
      );
    });
  });
}
