/// Tests for `lib/shared.dart`: the wire enums, `createZpTimestamp`,
/// `createZpMupid`, and `createZpCheckoutUrl`.
library;

import 'package:test/test.dart';
import 'package:zenpay_dart/zenpay_dart.dart';

void main() {
  group('ZpPluginMode', () {
    test('wire values match the swagger PaymentMode integers', () {
      expect(ZpPluginMode.makePayment.wireValue, 0);
      expect(ZpPluginMode.tokenise.wireValue, 1);
      expect(ZpPluginMode.customPayment.wireValue, 2);
      expect(ZpPluginMode.preauthorization.wireValue, 3);
    });

    test(
      'fromWireValue resolves a known value and throws on an unknown one',
      () {
        expect(ZpPluginMode.fromWireValue(3), ZpPluginMode.preauthorization);
        expect(() => ZpPluginMode.fromWireValue(9), throwsArgumentError);
      },
    );

    test('requiresPositiveAmount is true only for modes 0, 2, and 3', () {
      expect(ZpPluginMode.makePayment.requiresPositiveAmount, isTrue);
      expect(ZpPluginMode.tokenise.requiresPositiveAmount, isFalse);
      expect(ZpPluginMode.customPayment.requiresPositiveAmount, isTrue);
      expect(ZpPluginMode.preauthorization.requiresPositiveAmount, isTrue);
    });
  });

  test('ZpDisplayMode wire values', () {
    expect(ZpDisplayMode.modal.wireValue, 0);
    expect(ZpDisplayMode.redirectUrl.wireValue, 1);
  });

  test('ZpUserMode wire values', () {
    expect(ZpUserMode.customer.wireValue, 0);
    expect(ZpUserMode.merchant.wireValue, 1);
  });

  test('ZpOverrideFeePayer wire values', () {
    expect(ZpOverrideFeePayer.accountDefault.wireValue, 0);
    expect(ZpOverrideFeePayer.merchant.wireValue, 1);
    expect(ZpOverrideFeePayer.customer.wireValue, 2);
  });

  group('ZpPaymentStatus', () {
    test('wire values skip 2 and mark only 3 as successful', () {
      expect(ZpPaymentStatus.pending.wireValue, 0);
      expect(ZpPaymentStatus.error.wireValue, 1);
      expect(ZpPaymentStatus.successful.wireValue, 3);
      expect(ZpPaymentStatus.failed.wireValue, 4);
      expect(ZpPaymentStatus.cancelled.wireValue, 5);
      expect(ZpPaymentStatus.suppressed.wireValue, 6);
      expect(ZpPaymentStatus.inProgress.wireValue, 7);
    });

    test('only status 3 is successful', () {
      expect(ZpPaymentStatus.tryFromWireValue(3)?.isSuccessful, isTrue);
      for (final code in [0, 1, 4, 5, 6, 7]) {
        expect(ZpPaymentStatus.tryFromWireValue(code)?.isSuccessful, isFalse);
      }
    });
  });

  test('isZpPaymentSuccessful matches ZpPaymentStatus.isSuccessful', () {
    expect(isZpPaymentSuccessful(3), isTrue);
    for (final code in [0, 1, 4, 5, 6, 7]) {
      expect(isZpPaymentSuccessful(code), isFalse);
    }
  });

  test('isZpPaymentSuccessful returns false for an unknown wire code', () {
    expect(isZpPaymentSuccessful(99), isFalse);
  });

  test('createZpTimestamp returns a slice-19 UTC ISO 8601 string', () {
    final timestamp = createZpTimestamp();
    expect(
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$').hasMatch(timestamp.value),
      isTrue,
      reason: timestamp.value,
    );
  });

  test(
    'createZpMupid returns a 22-character base64url string with no padding',
    () {
      final mupid = createZpMupid();
      expect(mupid.value, hasLength(22));
      expect(mupid.value.contains('='), isFalse);
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(mupid.value), isTrue);
    },
  );

  test('createZpMupid returns distinct values across calls', () {
    expect(createZpMupid().value, isNot(createZpMupid().value));
  });

  group('createZpCheckoutUrl', () {
    ZpCheckoutOptions baseOptions() => ZpCheckoutOptions(
      url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
      merchantCode: 'ZenTest1',
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

    test('fails when neither callbackUrl nor redirectUrl is provided', () {
      final options = ZpCheckoutOptions(
        url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
        merchantCode: 'ZenTest1',
        apiKey: 'api-key-value',
        fingerprint: 'f'.padLeft(128, 'f'),
        merchantUniquePaymentId: const ZpMupid('mupid-0001'),
        timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
        customerEmail: 'jane@example.com',
        paymentAmount: '49.90',
        customerName: 'Jane Smith',
        customerReference: 'ORD-1001',
        // Omitting redirectUrl and callbackUrl
      );
      final result = createZpCheckoutUrl(options);
      expect(result, isA<ZpUrlFailure>());
      final failure = createZpCheckoutUrl(options) as ZpUrlFailure;
      expect(failure.message, contains('at least one of callbackUrl or redirectUrl'));
      expect(
        validateZpCheckoutUrlRequest(options)?.message,
        contains('at least one of callbackUrl or redirectUrl'),
      );
    });

    test('validateZpCheckoutUrlRequest returns null for a valid request', () {
      expect(validateZpCheckoutUrlRequest(baseOptions()), isNull);
    });

    test('builds a URL with correct path, renames, and auto isJsPlugin', () {
      final result = createZpCheckoutUrl(baseOptions());
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        final uri = Uri.parse(result.url);
        expect(uri.path, '/Online/v5/ZenTest1/Authorise');

        final params = uri.queryParameters;
        expect(params['__ApiKey'], 'api-key-value');
        expect(params['__Fingerprint'], 'f'.padLeft(128, 'f'));
        expect(params.containsKey('action'), isFalse);
        expect(params.containsKey('merchantCode'), isFalse);
        expect(params.containsKey('url'), isFalse);
        expect(params['isJsPlugin'], 'true');
        expect(params['mode'], '0');
        expect(params['redirectUrl'], 'https://merchant.example/return');
      }
    });

    test('omits every unset optional field instead of sending it empty', () {
      final result = createZpCheckoutUrl(baseOptions());
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        final params = Uri.parse(result.url).queryParameters;
        for (final key in [
          'callbackUrl',
          'sendConfirmationEmailToMerchant',
          'allowPayToOneOffPayment',
          'allowGooglePayOneOffPayment',
          'allowLatitudePayOneOffPayment',
          'allowSlicePayOneOffPayment',
          'allowWeChatPayOneOffPayment',
          'allowSaveCardInformation',
          'hideMerchantLogo',
          'redirectOnError',
          'customerNameLabel',
          'customerReferenceLabel',
          'paymentAmountLabel',
          'token',
          'AustralianBusinessNumber',
          'sku1',
          'sku2',
          'additionalReference',
          'contactNumber',
          'departureDate',
          'companyName',
        ]) {
          expect(params.containsKey(key), isFalse, reason: '$key should be omitted when unset, not sent as "$key="');
        }
      }
    });

    test(
      'encodes delimiter-bearing free text instead of splitting the query',
      () {
        final options = ZpCheckoutOptions(
          url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
          merchantCode: 'ZenTest1',
          apiKey: 'api-key-value',
          fingerprint: 'f'.padLeft(128, 'f'),
          merchantUniquePaymentId: const ZpMupid('mupid-0001'),
          timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
          customerEmail: 'jane@example.com',
          paymentAmount: '49.90',
          customerName: 'Jane & Jones #1', // Delimiter
          customerReference: 'ORD-1001',
          redirectUrl: 'https://merchant.example/return',
        );
        final result = createZpCheckoutUrl(options);
        expect(result, isA<ZpUrlSuccess>());
        if (result is ZpUrlSuccess) {
          expect(result.url, isNot(contains('#')));
          final params = Uri.parse(result.url).queryParameters;
          expect(params['customerName'], 'Jane & Jones #1');
        }
      },
    );

    test('percent-encodes a customerEmail with an "@" the same as other safe fields', () {
      final result = createZpCheckoutUrl(baseOptions());
      if (result is ZpUrlSuccess) {
        final params = Uri.parse(result.url).queryParameters;
        expect(params['customerEmail'], 'jane@example.com');
      }
    });

    test('an explicit isJsPlugin overrides the default', () {
      final result = createZpCheckoutUrl(
        ZpCheckoutOptions(
          url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
          merchantCode: 'ZenTest1',
          apiKey: 'api-key-value',
          fingerprint: 'f'.padLeft(128, 'f'),
          merchantUniquePaymentId: const ZpMupid('mupid-0001'),
          timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
          customerEmail: 'jane@example.com',
          paymentAmount: '49.90',
          customerName: 'Jane Smith',
          customerReference: 'ORD-1001',
          redirectUrl: 'https://merchant.example/return',
          isJsPlugin: false,
        ),
      );
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        expect(Uri.parse(result.url).queryParameters['isJsPlugin'], 'false');
      }
    });

    test('falls back to "Process Payment" when title is omitted', () {
      final result = createZpCheckoutUrl(baseOptions());
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        expect(Uri.parse(result.url).queryParameters['title'], 'Process Payment');
      }
    });

    test('falls back to "Tokenize Card" when title is omitted and mode is tokenise', () {
      final result = createZpCheckoutUrl(
        ZpCheckoutOptions(
          url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
          merchantCode: 'ZenTest1',
          apiKey: 'api-key-value',
          fingerprint: 'f'.padLeft(128, 'f'),
          merchantUniquePaymentId: const ZpMupid('mupid-0001'),
          timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
          customerEmail: 'jane@example.com',
          redirectUrl: 'https://merchant.example/return',
          mode: ZpPluginMode.tokenise,
        ),
      );
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        expect(Uri.parse(result.url).queryParameters['title'], 'Tokenize Card');
      }
    });

    test('an explicit title overrides the fallback', () {
      final options = ZpCheckoutOptions(
        url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
        merchantCode: 'ZenTest1',
        apiKey: 'api-key-value',
        fingerprint: 'f'.padLeft(128, 'f'),
        merchantUniquePaymentId: const ZpMupid('mupid-0001'),
        timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
        customerEmail: 'jane@example.com',
        paymentAmount: '49.90',
        customerName: 'Jane Smith',
        customerReference: 'ORD-1001',
        redirectUrl: 'https://merchant.example/return',
        title: 'Book Your Stay',
      );
      final result = createZpCheckoutUrl(options);
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        expect(Uri.parse(result.url).queryParameters['title'], 'Book Your Stay');
      }
    });

    test('height is 450px for tokenise mode and 725px for every other mode', () {
      final tokenise = createZpCheckoutUrl(
        ZpCheckoutOptions(
          url: 'https://pay.sandbox.b2bpay.com.au/Online/v5',
          merchantCode: 'ZenTest1',
          apiKey: 'api-key-value',
          fingerprint: 'f'.padLeft(128, 'f'),
          merchantUniquePaymentId: const ZpMupid('mupid-0001'),
          timestamp: const ZpTimestamp('2026-01-15T10:30:00'),
          customerEmail: 'jane@example.com',
          redirectUrl: 'https://merchant.example/return',
          mode: ZpPluginMode.tokenise,
        ),
      );
      expect(tokenise, isA<ZpUrlSuccess>());
      if (tokenise is ZpUrlSuccess) {
        expect(tokenise.height, '450px');
      }

      final payment = createZpCheckoutUrl(baseOptions());
      expect(payment, isA<ZpUrlSuccess>());
      if (payment is ZpUrlSuccess) {
        expect(payment.height, '725px');
      }
    });

    test('maxWidth is always "600px", regardless of mode', () {
      final result = createZpCheckoutUrl(baseOptions());
      expect(result, isA<ZpUrlSuccess>());
      if (result is ZpUrlSuccess) {
        expect(result.maxWidth, '600px');
      }
    });
  });
}
