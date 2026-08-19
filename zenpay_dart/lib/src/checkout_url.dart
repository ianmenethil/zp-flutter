/// Hosted-checkout Authorise URL construction.
///
/// Every query value is percent-encoded exactly once via [Uri]. ZenPay's own
/// browser plugin builds the query with `URLSearchParams` then
/// `decodeURIComponent`s the whole string back, undoing every escape — a
/// live `&`/`#` in free text would split or truncate the query there. This
/// builder does not have that bug: reserved characters stay escaped.
library;

import 'crypto.dart';
import 'defaults.dart';
import 'enums.dart';

const _authoriseActionPath = 'Authorise';
const _errApiKeyOrFingerprintEmpty = 'apiKey and fingerprint must not be empty';
const _errMerchantCodeEmpty = 'merchantCode must not be empty';
const _errCallbackAndRedirectEmpty =
    'callbackUrl and redirectUrl cannot both be empty';
const _errDepartureDateRequired =
    'departureDate is required when allowSlicePayOneOffPayment is true';

final _hcpEndpointPattern = RegExp(
  r'^https://(pay|payuat|pay\.sandbox)\.'
  r'(travelpay|childcareeasypay|zenpay|b2bpay|schooleasypay'
  r'|thoroughbredpayments|rentalrewards)'
  r'\.com\.au/[Oo]nline/v[45]/?$',
);

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The Authorise request: every field ZenPay's hosted-checkout endpoint accepts, minus browser-only concerns such as theme, fonts, modal sizing, and lifecycle callbacks.
class const ZpCheckoutOptions({
  /// The HCP Authorise endpoint, for example
  /// `https://pay.sandbox.travelpay.com.au/Online/v5`.
  required final String url,

  /// Merchant API key sent as `__ApiKey`.
  required final String apiKey,

  /// Per-transaction SHA3-512 digest from [createZpFingerprint], sent as
  /// `__Fingerprint`.
  required final String fingerprint,

  /// Merchant identifier used in the Authorise URL path.
  required final String merchantCode,

  /// Timestamp used when computing [fingerprint].
  required final ZpTimestamp timestamp,

  /// Merchant Unique Payment Identifier.
  required final ZpMupid merchantUniquePaymentId,

  /// Customer email address.
  required final String customerEmail,

  /// Server-to-server callback destination.
  final String? callbackUrl,

  /// Browser redirect destination after payment.
  final String? redirectUrl,

  /// Checkout plugin mode.
  final ZpPluginMode mode = ZpCheckoutDefaults.mode,

  /// Override fee payer setting.
  final ZpOverrideFeePayer overrideFeePayer =
      ZpCheckoutDefaults.overrideFeePayer,

  /// Target user mode.
  final ZpUserMode userMode = ZpCheckoutDefaults.userMode,

  /// Target display mode.
  final ZpDisplayMode displayMode = ZpCheckoutDefaults.displayMode,

  /// Whether to hide the top header.
  final bool hideHeader = ZpCheckoutDefaults.hideHeader,

  /// Whether to hide terms and conditions.
  final bool hideTermsAndConditions = ZpCheckoutDefaults.hideTermsAndConditions,

  /// Whether to display fees during tokenisation.
  final bool showFeeOnTokenising = ZpCheckoutDefaults.showFeeOnTokenising,

  /// Whether to display failed-payment fees during tokenisation.
  final bool showFailedPaymentFeeOnTokenising =
      ZpCheckoutDefaults.showFailedPaymentFeeOnTokenising,

  /// Whether to send payment confirmation to the customer.
  final bool sendConfirmationEmailToCustomer =
      ZpCheckoutDefaults.sendConfirmationEmailToCustomer,

  /// Marks the request as coming from a ZenPay checkout plugin, sent as
  /// `isJsPlugin`. `true` unless overridden.
  final bool isJsPlugin = ZpCheckoutDefaults.isJsPlugin,

  /// Whether to send payment confirmation to the merchant.
  final bool? sendConfirmationEmailToMerchant,

  /// Allow bank-account payment.
  final bool allowBankAcOneOffPayment =
      ZpCheckoutDefaults.allowBankAcOneOffPayment,

  /// Allow PayID payment.
  final bool allowPayIdOneOffPayment =
      ZpCheckoutDefaults.allowPayIdOneOffPayment,

  /// Allow PayTo payment.
  final bool? allowPayToOneOffPayment,

  /// Allow Apple Pay payment.
  final bool allowApplePayOneOffPayment =
      ZpCheckoutDefaults.allowApplePayOneOffPayment,

  /// Allow Google Pay payment.
  final bool? allowGooglePayOneOffPayment,

  /// Allow UnionPay payment.
  final bool allowUnionPayOneOffPayment =
      ZpCheckoutDefaults.allowUnionPayOneOffPayment,

  /// Allow Alipay+ payment.
  final bool allowAliPayPlusOneOffPayment =
      ZpCheckoutDefaults.allowAliPayPlusOneOffPayment,

  /// Allow LatitudePay payment.
  final bool? allowLatitudePayOneOffPayment,

  /// Allow Slice Pay payment.
  ///
  /// Requires [departureDate] when `true`.
  final bool? allowSlicePayOneOffPayment,

  /// Allow WeChat Pay payment.
  final bool? allowWeChatPayOneOffPayment,

  /// Allow the customer to save their card.
  final bool? allowSaveCardUserOption,

  /// Whether to hide the merchant logo.
  final bool? hideMerchantLogo,

  /// Whether errors should redirect to the return URL.
  final bool? redirectOnError,

  /// Customer name.
  ///
  /// Required with [customerReference] for payment modes 0 and 2.
  final String? customerName,

  /// Customer reference.
  ///
  /// Required with [customerName] for payment modes 0 and 2.
  final String? customerReference,

  /// Payment amount in dollars.
  final Object? paymentAmount,

  /// Custom customer-name field label.
  final String? customerNameLabel,

  /// Custom customer-reference field label.
  final String? customerReferenceLabel,

  /// Custom payment-amount field label.
  final String? paymentAmountLabel,

  /// Custom checkout page title.
  final String? title,

  /// Card proxy sent to ZenPay as `token`.
  final String? cardProxy,

  /// Australian Business Number sent as `AustralianBusinessNumber`.
  final String? abn,

  /// Product SKU 1.
  final String? sku1,

  /// Product SKU 2.
  final String? sku2,

  /// Additional merchant reference.
  final String? additionalReference,

  /// Customer contact number.
  final String? contactNumber,

  /// Departure date required for Slice Pay.
  final String? departureDate,

  /// Customer company name.
  final String? companyName,
});

/// Result of [createZpCheckoutUrl].
///
/// Exhaustively pattern-match with a `switch` over [ZpUrlSuccess]
/// and [ZpUrlFailure].
sealed class ZpUrlResult {
  const ZpUrlResult();
}

/// A successfully built checkout URL.
final class const ZpUrlSuccess(
  /// Fully assembled and percent-encoded checkout URL.
  final String url,
) extends ZpUrlResult;

/// A checkout URL validation failure.
final class const ZpUrlFailure(
  /// Why URL construction failed.
  final String message,
) extends ZpUrlResult;

/// Validates [request] without building the URL.
///
/// Returns `null` when [request] is valid.
ZpUrlFailure? validateZpCheckoutUrlRequest(ZpCheckoutOptions request) {
  if (request.apiKey.isEmpty || request.fingerprint.isEmpty) {
    return const ZpUrlFailure(_errApiKeyOrFingerprintEmpty);
  }

  if (!_hcpEndpointPattern.hasMatch(request.url)) {
    return ZpUrlFailure(
      'url "${request.url}" is not a recognized ZenPay HCP endpoint',
    );
  }

  if (request.merchantCode.isEmpty) {
    return const ZpUrlFailure(_errMerchantCodeEmpty);
  }

  if ((request.callbackUrl?.isEmpty ?? true) &&
      (request.redirectUrl?.isEmpty ?? true)) {
    return const ZpUrlFailure(_errCallbackAndRedirectEmpty);
  }

  if (!_emailPattern.hasMatch(request.customerEmail)) {
    return ZpUrlFailure(
      'customerEmail "${request.customerEmail}" is not a valid email',
    );
  }

  final requiresCustomer =
      request.mode == ZpPluginMode.makePayment ||
      request.mode == ZpPluginMode.customPayment;

  if (requiresCustomer &&
      ((request.customerName?.isEmpty ?? true) ||
          (request.customerReference?.isEmpty ?? true))) {
    return ZpUrlFailure(
      'customerName and customerReference are required '
      'for mode ${request.mode.wireValue}',
    );
  }

  if (request.mode.requiresPositiveAmount) {
    final amount = num.tryParse(request.paymentAmount?.toString().trim() ?? '');

    if (amount == null || amount <= 0) {
      return ZpUrlFailure(
        'paymentAmount must be a positive number '
        'for mode ${request.mode.wireValue}',
      );
    }
  }

  if (request.allowSlicePayOneOffPayment == true &&
      (request.departureDate?.isEmpty ?? true)) {
    return const ZpUrlFailure(_errDepartureDateRequired);
  }

  return null;
}

Map<String, String> _buildQueryParams(
  ZpCheckoutOptions request,
) => <String, String>{
  '__ApiKey': request.apiKey,
  '__Fingerprint': request.fingerprint,
  'timestamp': request.timestamp.value,
  'merchantUniquePaymentId': request.merchantUniquePaymentId.value,
  'customerEmail': request.customerEmail,
  'mode': request.mode.wireValue.toString(),
  'overrideFeePayer': request.overrideFeePayer.wireValue.toString(),
  'userMode': request.userMode.wireValue.toString(),
  'displayMode': request.displayMode.wireValue.toString(),
  'hideHeader': request.hideHeader.toString(),
  'hideTermsAndConditions': request.hideTermsAndConditions.toString(),
  'showFeeOnTokenising': request.showFeeOnTokenising.toString(),
  'showFailedPaymentFeeOnTokenising': request.showFailedPaymentFeeOnTokenising
      .toString(),
  'sendConfirmationEmailToCustomer': request.sendConfirmationEmailToCustomer
      .toString(),
  'allowBankAcOneOffPayment': request.allowBankAcOneOffPayment.toString(),
  'allowPayIdOneOffPayment': request.allowPayIdOneOffPayment.toString(),
  'allowApplePayOneOffPayment': request.allowApplePayOneOffPayment.toString(),
  'allowUnionPayOneOffPayment': request.allowUnionPayOneOffPayment.toString(),
  'allowAliPayPlusOneOffPayment': request.allowAliPayPlusOneOffPayment
      .toString(),
  'isJsPlugin': request.isJsPlugin.toString(),
  'callbackUrl': ?request.callbackUrl,
  'redirectUrl': ?request.redirectUrl,
  'sendConfirmationEmailToMerchant': ?request.sendConfirmationEmailToMerchant
      ?.toString(),
  'allowPayToOneOffPayment': ?request.allowPayToOneOffPayment?.toString(),
  'allowGooglePayOneOffPayment': ?request.allowGooglePayOneOffPayment
      ?.toString(),
  'allowLatitudePayOneOffPayment': ?request.allowLatitudePayOneOffPayment
      ?.toString(),
  'allowSlicePayOneOffPayment': ?request.allowSlicePayOneOffPayment?.toString(),
  'allowWeChatPayOneOffPayment': ?request.allowWeChatPayOneOffPayment
      ?.toString(),
  'allowSaveCardUserOption': ?request.allowSaveCardUserOption?.toString(),
  'hideMerchantLogo': ?request.hideMerchantLogo?.toString(),
  'redirectOnError': ?request.redirectOnError?.toString(),
  'customerName': ?request.customerName,
  'customerReference': ?request.customerReference,
  'paymentAmount': ?request.paymentAmount?.toString(),
  'customerNameLabel': ?request.customerNameLabel,
  'customerReferenceLabel': ?request.customerReferenceLabel,
  'paymentAmountLabel': ?request.paymentAmountLabel,
  'title': ?request.title,
  'token': ?request.cardProxy,
  'AustralianBusinessNumber': ?request.abn,
  'sku1': ?request.sku1,
  'sku2': ?request.sku2,
  'additionalReference': ?request.additionalReference,
  'contactNumber': ?request.contactNumber,
  'departureDate': ?request.departureDate,
  'companyName': ?request.companyName,
};

/// Builds the hosted-checkout Authorise URL from [request].
ZpUrlResult createZpCheckoutUrl(ZpCheckoutOptions request) {
  final failure = validateZpCheckoutUrlRequest(request);

  if (failure != null) {
    return failure;
  }

  final base = Uri.parse(request.url);

  final basePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;

  final url = base.replace(
    path: '$basePath/${request.merchantCode}/$_authoriseActionPath',
    queryParameters: _buildQueryParams(request),
  );

  return ZpUrlSuccess(url.toString());
}
