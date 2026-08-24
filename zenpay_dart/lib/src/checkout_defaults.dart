/// Default option and UI-hint values applied when the caller omits them.
///
/// [ZpCheckoutDefaults] is internal — deliberately not exported from
/// `zenpay_dart.dart`. Two fields intentionally have no entry here:
/// - `action: "Authorise"` is not caller-configurable; it is the URL path
///   segment, held in `checkout_url.dart`.
/// - `onPluginClose` is a browser modal callback. The Flutter equivalent is the
///   `ZpPresentationDismissed` outcome, not a launch option.
///
/// [ZpUiDefaults] is a separate namespace: output/rendering hints applied at
/// URL-build time, not merged into the request.
library;

import 'package:zenpay_dart/src/models/checkout_options.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// The default value for every optional [ZpCheckoutOptions] field that has one.
abstract final class ZpCheckoutDefaults {
  /// Plugin operating mode.
  static const ZpPluginMode mode = ZpPluginMode.makePayment;

  /// Who absorbs the surcharge.
  static const ZpOverrideFeePayer overrideFeePayer = ZpOverrideFeePayer.accountDefault;

  /// Who operates the checkout.
  static const ZpUserMode userMode = ZpUserMode.customer;

  /// How the checkout is presented.
  ///
  /// Defaults to Redirect, not Modal: Modal renders the checkout in an
  /// iframe inside a host page — impossible from a Custom Tab or
  /// SFSafariViewController, which is all this SDK launches. Redirect is
  /// the only mode that can work here.
  static const ZpDisplayMode displayMode = ZpDisplayMode.redirectUrl;

  /// Whether the hosted page hides its header.
  static const bool hideHeader = true;

  /// Whether terms and conditions are hidden.
  static const bool hideTermsAndConditions = false;

  /// Whether the surcharge shows while tokenising.
  static const bool showFeeOnTokenising = false;

  /// Whether a failed-payment surcharge shows while tokenising.
  static const bool showFailedPaymentFeeOnTokenising = false;

  /// Whether ZenPay emails the customer a receipt.
  static const bool sendConfirmationEmailToCustomer = false;

  /// Whether bank-account one-off payment is offered.
  static const bool allowBankAcOneOffPayment = false;

  /// Whether PayID one-off payment is offered.
  static const bool allowPayIdOneOffPayment = false;

  /// Whether Apple Pay one-off payment is offered.
  static const bool allowApplePayOneOffPayment = true;

  /// Whether UnionPay one-off payment is offered.
  static const bool allowUnionPayOneOffPayment = true;

  /// Whether AliPay+ one-off payment is offered.
  static const bool allowAliPayPlusOneOffPayment = true;

  /// Value sent as the `isJsPlugin` query parameter.
  static const bool isJsPlugin = true;
}

/// Default UI/output hints applied when the caller omits them.
abstract final class ZpUiDefaults {
  /// Checkout title used when the caller's `title` option is omitted or empty,
  /// for every mode except `ZpPluginMode.tokenise`.
  static const titleFallback = 'Process Payment';

  /// Checkout title used when the caller's `title` option is omitted or empty
  /// and `mode` is `ZpPluginMode.tokenise`.
  static const titleFallbackTokenise = 'Tokenize Card';

  /// Modal max-width hint (px) — fixed, not mode-dependent, not
  /// caller-overridable. Informational only: a host rendering an
  /// iframe/modal is CSS-driven and may ignore it.
  static const maxWidth = '600px';

  /// Min-height hint (px) for `ZpPluginMode.tokenise`.
  static const heightTokenise = '450px';

  /// Min-height hint (px) for every other mode.
  static const heightDefault = '725px';
}
