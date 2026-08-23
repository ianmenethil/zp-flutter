/// Models for the hosted-checkout Authorise request options.
library;

import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/defaults.dart';
import 'package:zenpay_dart/src/fingerprint.dart';
import 'package:zenpay_dart/src/models/enums.dart';

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
  final ZpOverrideFeePayer overrideFeePayer = ZpCheckoutDefaults.overrideFeePayer,

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
  final bool showFailedPaymentFeeOnTokenising = ZpCheckoutDefaults.showFailedPaymentFeeOnTokenising,

  /// Whether to send payment confirmation to the customer.
  final bool sendConfirmationEmailToCustomer = ZpCheckoutDefaults.sendConfirmationEmailToCustomer,

  /// Marks the request as coming from a ZenPay checkout plugin, sent as
  /// `isJsPlugin`. `true` unless overridden.
  final bool isJsPlugin = ZpCheckoutDefaults.isJsPlugin,

  /// Whether to send payment confirmation to the merchant.
  final bool? sendConfirmationEmailToMerchant,

  /// Allow bank-account payment.
  final bool allowBankAcOneOffPayment = ZpCheckoutDefaults.allowBankAcOneOffPayment,

  /// Allow PayID payment.
  final bool allowPayIdOneOffPayment = ZpCheckoutDefaults.allowPayIdOneOffPayment,

  /// Allow PayTo payment.
  final bool? allowPayToOneOffPayment,

  /// Allow Apple Pay payment.
  final bool allowApplePayOneOffPayment = ZpCheckoutDefaults.allowApplePayOneOffPayment,

  /// Allow Google Pay payment.
  final bool? allowGooglePayOneOffPayment,

  /// Allow UnionPay payment.
  final bool allowUnionPayOneOffPayment = ZpCheckoutDefaults.allowUnionPayOneOffPayment,

  /// Allow Alipay+ payment.
  final bool allowAliPayPlusOneOffPayment = ZpCheckoutDefaults.allowAliPayPlusOneOffPayment,

  /// Allow LatitudePay payment.
  final bool? allowLatitudePayOneOffPayment,

  /// Allow Slice Pay payment.
  ///
  /// Requires [departureDate] when `true`.
  final bool? allowSlicePayOneOffPayment,

  /// Allow WeChat Pay payment.
  final bool? allowWeChatPayOneOffPayment,

  /// Allow the customer to save their card.
  final bool? allowSaveCardInformation,

  /// Whether to hide the merchant logo.
  final bool? hideMerchantLogo,

  /// Whether errors should redirect to the return URL.
  final bool? redirectOnError,

  /// Required with [customerReference] for payment modes 0 and 2.
  final String? customerName,

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
}) {}
