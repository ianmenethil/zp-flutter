/// Hosted-checkout Authorise URL construction.
///
/// Every query value is percent-encoded exactly once via [Uri]. ZenPay's own
/// browser plugin builds the query with `URLSearchParams` then
/// `decodeURIComponent`s the whole string back, undoing every escape — a
/// live `&`/`#` in free text would split or truncate the query there. This
/// builder does not have that bug: reserved characters stay escaped.
library;

import 'package:zenpay_dart/src/constants.dart';
import 'package:zenpay_dart/src/defaults.dart';
import 'package:zenpay_dart/src/models/checkout_options.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// Result of [createZpCheckoutUrl].
///
/// Exhaustively pattern-match with a `switch` over [ZpUrlSuccess]
/// and [ZpUrlFailure].
sealed class ZpUrlResult {
  /// Base constructor for checkout URL results.
  const ZpUrlResult();
}

/// A successfully built checkout URL.
final class ZpUrlSuccess extends ZpUrlResult {
  /// Creates a [ZpUrlSuccess] result with the assembled [url], [height], and
  /// [maxWidth] hints.
  const ZpUrlSuccess(this.url, {required this.height, this.maxWidth = ZpUiDefaults.maxWidth});

  /// Fully assembled and percent-encoded checkout URL.
  final String url;

  /// Min-height hint in px — [ZpUiDefaults.heightTokenise] for
  /// [ZpPluginMode.tokenise], [ZpUiDefaults.heightDefault] otherwise.
  final String height;

  /// Max-width hint in px — always [ZpUiDefaults.maxWidth]. Informational
  /// only; a rendering surface may ignore it.
  final String maxWidth;
}

/// A checkout URL validation failure.
final class ZpUrlFailure extends ZpUrlResult {
  /// Creates a [ZpUrlFailure] result with the failure [message].
  const ZpUrlFailure(this.message);

  /// Why URL construction failed.
  final String message;
}

/// Validates [request] without building the URL.
///
/// Returns `null` when [request] is valid.
ZpUrlFailure? validateZpCheckoutUrlRequest(ZpCheckoutOptions request) {
  if (request.apiKey.isEmpty || request.fingerprint.isEmpty) {
    return const ZpUrlFailure(ZpErrors.apiKeyOrFingerprintEmpty);
  }

  if (!ZpPatterns.hcpEndpoint.hasMatch(request.url)) {
    return ZpUrlFailure(
      'url "${request.url}" is not a recognized ZenPay HCP endpoint',
    );
  }

  if (request.merchantCode.isEmpty) {
    return const ZpUrlFailure(ZpErrors.merchantCodeEmpty);
  }

  if ((request.callbackUrl?.isEmpty ?? true) && (request.redirectUrl?.isEmpty ?? true)) {
    return const ZpUrlFailure(ZpErrors.callbackOrRedirectEmpty);
  }

  if (!ZpPatterns.email.hasMatch(request.customerEmail)) {
    return ZpUrlFailure(
      'customerEmail "${request.customerEmail}" is not a valid email',
    );
  }

  if (request.mode == ZpPluginMode.makePayment || request.mode == ZpPluginMode.customPayment) {
    if ((request.customerName?.isEmpty ?? true) || (request.customerReference?.isEmpty ?? true)) {
      return const ZpUrlFailure(ZpErrors.customerNameAndRefRequired);
    }
  }

  if (request.mode.requiresPositiveAmount) {
    final amount = num.tryParse(request.paymentAmount?.toString().trim() ?? '');

    if (amount == null || amount <= 0) {
      return const ZpUrlFailure(ZpErrors.amountRequired);
    }
  }

  if (request.allowSlicePayOneOffPayment == true && (request.departureDate?.isEmpty ?? true)) {
    return const ZpUrlFailure(ZpErrors.slicePayDateRequired);
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
  'showFailedPaymentFeeOnTokenising': request.showFailedPaymentFeeOnTokenising.toString(),
  'sendConfirmationEmailToCustomer': request.sendConfirmationEmailToCustomer.toString(),
  'allowBankAcOneOffPayment': request.allowBankAcOneOffPayment.toString(),
  'allowPayIdOneOffPayment': request.allowPayIdOneOffPayment.toString(),
  'allowApplePayOneOffPayment': request.allowApplePayOneOffPayment.toString(),
  'allowUnionPayOneOffPayment': request.allowUnionPayOneOffPayment.toString(),
  'allowAliPayPlusOneOffPayment': request.allowAliPayPlusOneOffPayment.toString(),
  'isJsPlugin': request.isJsPlugin.toString(),
  'callbackUrl': request.callbackUrl ?? '',
  'redirectUrl': request.redirectUrl ?? '',
  'sendConfirmationEmailToMerchant': request.sendConfirmationEmailToMerchant?.toString() ?? '',
  'allowPayToOneOffPayment': request.allowPayToOneOffPayment?.toString() ?? '',
  'allowGooglePayOneOffPayment': request.allowGooglePayOneOffPayment?.toString() ?? '',
  'allowLatitudePayOneOffPayment': request.allowLatitudePayOneOffPayment?.toString() ?? '',
  'allowSlicePayOneOffPayment': request.allowSlicePayOneOffPayment?.toString() ?? '',
  'allowWeChatPayOneOffPayment': request.allowWeChatPayOneOffPayment?.toString() ?? '',
  'allowSaveCardUserOption': request.allowSaveCardUserOption?.toString() ?? '',
  'hideMerchantLogo': request.hideMerchantLogo?.toString() ?? '',
  'redirectOnError': request.redirectOnError?.toString() ?? '',
  'customerName': request.customerName ?? '',
  'customerReference': request.customerReference ?? '',
  // Omitted when null: an absent amount must not become `paymentAmount=`.
  if (request.paymentAmount != null) 'paymentAmount': request.paymentAmount!.toString(),
  'customerNameLabel': request.customerNameLabel ?? '',
  'customerReferenceLabel': request.customerReferenceLabel ?? '',
  'paymentAmountLabel': request.paymentAmountLabel ?? '',
  'title': (request.title != null && request.title!.isNotEmpty)
      ? request.title!
      : (request.mode == ZpPluginMode.tokenise ? ZpUiDefaults.titleFallbackTokenise : ZpUiDefaults.titleFallback),
  'token': request.cardProxy ?? '',
  'AustralianBusinessNumber': request.abn ?? '',
  'sku1': request.sku1 ?? '',
  'sku2': request.sku2 ?? '',
  'additionalReference': request.additionalReference ?? '',
  'contactNumber': request.contactNumber ?? '',
  'departureDate': request.departureDate ?? '',
  'companyName': request.companyName ?? '',
};

/// Builds the hosted-checkout Authorise URL from [request].
ZpUrlResult createZpCheckoutUrl(ZpCheckoutOptions request) {
  final failure = validateZpCheckoutUrlRequest(request);

  if (failure != null) {
    return failure;
  }

  final base = Uri.parse(request.url);

  final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;

  // Uri.replace(queryParameters:) drops `=` for empty-string values; build the
  // query manually so every param matches ZenPay's own URLSearchParams output.
  final query = _buildQueryParams(request).entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&');

  final url = base.replace(
    path: '$basePath/${request.merchantCode}/${ZpCore.authoriseActionPath}',
    query: query,
  );

  final height = request.mode == ZpPluginMode.tokenise ? ZpUiDefaults.heightTokenise : ZpUiDefaults.heightDefault;

  return ZpUrlSuccess(url.toString(), height: height);
}
