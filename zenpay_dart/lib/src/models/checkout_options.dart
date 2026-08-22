/// Models for the hosted-checkout Authorise request options.
library;

import 'package:zenpay_dart/src/crypto.dart';
import 'package:zenpay_dart/src/defaults.dart';
import 'package:zenpay_dart/src/fingerprint.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// The Authorise request: every field ZenPay's hosted-checkout endpoint accepts, minus browser-only concerns such as theme, fonts, modal sizing, and lifecycle callbacks.
class ZpCheckoutOptions {
  /// Creates a [ZpCheckoutOptions] instance.
  const ZpCheckoutOptions({
    required this.url,
    required this.apiKey,
    required this.fingerprint,
    required this.merchantCode,
    required this.timestamp,
    required this.merchantUniquePaymentId,
    required this.customerEmail,
    this.callbackUrl,
    this.redirectUrl,
    this.mode = ZpCheckoutDefaults.mode,
    this.overrideFeePayer = ZpCheckoutDefaults.overrideFeePayer,
    this.userMode = ZpCheckoutDefaults.userMode,
    this.displayMode = ZpCheckoutDefaults.displayMode,
    this.hideHeader = ZpCheckoutDefaults.hideHeader,
    this.hideTermsAndConditions = ZpCheckoutDefaults.hideTermsAndConditions,
    this.showFeeOnTokenising = ZpCheckoutDefaults.showFeeOnTokenising,
    this.showFailedPaymentFeeOnTokenising = ZpCheckoutDefaults.showFailedPaymentFeeOnTokenising,
    this.sendConfirmationEmailToCustomer = ZpCheckoutDefaults.sendConfirmationEmailToCustomer,
    this.isJsPlugin = ZpCheckoutDefaults.isJsPlugin,
    this.sendConfirmationEmailToMerchant,
    this.allowBankAcOneOffPayment = ZpCheckoutDefaults.allowBankAcOneOffPayment,
    this.allowPayIdOneOffPayment = ZpCheckoutDefaults.allowPayIdOneOffPayment,
    this.allowPayToOneOffPayment,
    this.allowApplePayOneOffPayment = ZpCheckoutDefaults.allowApplePayOneOffPayment,
    this.allowGooglePayOneOffPayment,
    this.allowUnionPayOneOffPayment = ZpCheckoutDefaults.allowUnionPayOneOffPayment,
    this.allowAliPayPlusOneOffPayment = ZpCheckoutDefaults.allowAliPayPlusOneOffPayment,
    this.allowLatitudePayOneOffPayment,
    this.allowSlicePayOneOffPayment,
    this.allowWeChatPayOneOffPayment,
    this.allowSaveCardUserOption,
    this.hideMerchantLogo,
    this.redirectOnError,
    this.customerName,
    this.customerReference,
    this.paymentAmount,
    this.customerNameLabel,
    this.customerReferenceLabel,
    this.paymentAmountLabel,
    this.title,
    this.cardProxy,
    this.abn,
    this.sku1,
    this.sku2,
    this.additionalReference,
    this.contactNumber,
    this.departureDate,
    this.companyName,
  });

  /// The HCP Authorise endpoint, for example
  /// `https://pay.sandbox.travelpay.com.au/Online/v5`.
  final String url;

  /// Merchant API key sent as `__ApiKey`.
  final String apiKey;

  /// Per-transaction SHA3-512 digest from [createZpFingerprint], sent as
  /// `__Fingerprint`.
  final String fingerprint;

  /// Merchant identifier used in the Authorise URL path.
  final String merchantCode;

  /// Timestamp used when computing [fingerprint].
  final ZpTimestamp timestamp;

  /// Merchant Unique Payment Identifier.
  final ZpMupid merchantUniquePaymentId;

  /// Customer email address.
  final String customerEmail;

  /// Server-to-server callback destination.
  final String? callbackUrl;

  /// Browser redirect destination after payment.
  final String? redirectUrl;

  /// Checkout plugin mode.
  final ZpPluginMode mode;

  /// Override fee payer setting.
  final ZpOverrideFeePayer overrideFeePayer;

  /// Target user mode.
  final ZpUserMode userMode;

  /// Target display mode.
  final ZpDisplayMode displayMode;

  /// Whether to hide the top header.
  final bool hideHeader;

  /// Whether to hide terms and conditions.
  final bool hideTermsAndConditions;

  /// Whether to display fees during tokenisation.
  final bool showFeeOnTokenising;

  /// Whether to display failed-payment fees during tokenisation.
  final bool showFailedPaymentFeeOnTokenising;

  /// Whether to send payment confirmation to the customer.
  final bool sendConfirmationEmailToCustomer;

  /// Marks the request as coming from a ZenPay checkout plugin, sent as
  /// `isJsPlugin`. `true` unless overridden.
  final bool isJsPlugin;

  /// Whether to send payment confirmation to the merchant.
  final bool? sendConfirmationEmailToMerchant;

  /// Allow bank-account payment.
  final bool allowBankAcOneOffPayment;

  /// Allow PayID payment.
  final bool allowPayIdOneOffPayment;

  /// Allow PayTo payment.
  final bool? allowPayToOneOffPayment;

  /// Allow Apple Pay payment.
  final bool allowApplePayOneOffPayment;

  /// Allow Google Pay payment.
  final bool? allowGooglePayOneOffPayment;

  /// Allow UnionPay payment.
  final bool allowUnionPayOneOffPayment;

  /// Allow Alipay+ payment.
  final bool allowAliPayPlusOneOffPayment;

  /// Allow LatitudePay payment.
  final bool? allowLatitudePayOneOffPayment;

  /// Allow Slice Pay payment.
  ///
  /// Requires [departureDate] when `true`.
  final bool? allowSlicePayOneOffPayment;

  /// Allow WeChat Pay payment.
  final bool? allowWeChatPayOneOffPayment;

  /// Allow the customer to save their card.
  final bool? allowSaveCardUserOption;

  /// Whether to hide the merchant logo.
  final bool? hideMerchantLogo;

  /// Whether errors should redirect to the return URL.
  final bool? redirectOnError;

  /// Required with [customerReference] for payment modes 0 and 2.
  final String? customerName;

  /// Required with [customerName] for payment modes 0 and 2.
  final String? customerReference;

  /// Payment amount in dollars.
  final Object? paymentAmount;

  /// Custom customer-name field label.
  final String? customerNameLabel;

  /// Custom customer-reference field label.
  final String? customerReferenceLabel;

  /// Custom payment-amount field label.
  final String? paymentAmountLabel;

  /// Custom checkout page title.
  final String? title;

  /// Card proxy sent to ZenPay as `token`.
  final String? cardProxy;

  /// Australian Business Number sent as `AustralianBusinessNumber`.
  final String? abn;

  /// Product SKU 1.
  final String? sku1;

  /// Product SKU 2.
  final String? sku2;

  /// Additional merchant reference.
  final String? additionalReference;

  /// Customer contact number.
  final String? contactNumber;

  /// Departure date required for Slice Pay.
  final String? departureDate;

  /// Customer company name.
  final String? companyName;
}
