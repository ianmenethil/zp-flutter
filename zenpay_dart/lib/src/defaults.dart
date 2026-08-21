/// Default option and UI-hint values applied when the caller omits them.
///
/// [ZpCheckoutDefaults] mirrors the TypeScript SDK's `defaults.ts` 1:1 so the
/// two can be diffed as a unit when either side changes. Internal —
/// deliberately not exported from `zenpay_dart.dart`, matching the TypeScript
/// package, which declares `defaults` but exports neither the value nor its
/// type.
///
/// Two of the sixteen TypeScript keys have no entry in [ZpCheckoutDefaults]:
/// - `action: "Authorise"` is not caller-configurable; it is the URL path
///   segment, held in `checkout_url.dart`.
/// - `onPluginClose` is a browser modal callback. The Flutter equivalent is the
///   `ZpPresentationDismissed` outcome, not a launch option.
///
/// [ZpUiDefaults] ports a *different* TypeScript file — `ZP_DEFAULTS` in
/// `plugin/core/constants.ts` — output/rendering hints applied at URL-build
/// time, not merged into the request. Its title fallbacks additionally go
/// beyond that TypeScript source: see the class doc for details.
library;

import 'package:zenpay_dart/src/models/checkout_options.dart';
import 'package:zenpay_dart/src/models/enums.dart';

/// The default value for every optional [ZpCheckoutOptions] field that has one.
abstract final class ZpCheckoutDefaults {
  /// Plugin operating mode. TypeScript: `mode: 0`.
  static const ZpPluginMode mode = ZpPluginMode.makePayment;

  /// Who absorbs the surcharge. TypeScript: `overrideFeePayer: 0`.
  static const ZpOverrideFeePayer overrideFeePayer = ZpOverrideFeePayer.accountDefault;

  /// Who operates the checkout. TypeScript: `userMode: 0`.
  static const ZpUserMode userMode = ZpUserMode.customer;

  /// How the checkout is presented.
  ///
  /// **Diverges from TypeScript**, which defaults to `displayMode: 0` (Modal).
  /// Modal renders the checkout in an iframe inside a host page — impossible
  /// from a Custom Tab or SFSafariViewController, which is all this SDK
  /// launches. Redirect is the only mode that can work here.
  static const ZpDisplayMode displayMode = ZpDisplayMode.redirectUrl;

  /// Whether the hosted page hides its header. TypeScript: `hideHeader: true`.
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
///
/// The height and [maxWidth] hints mirror the TypeScript SDK's `ZP_DEFAULTS`
/// (`plugin/core/constants.ts`). The title fallbacks do not: TypeScript has a
/// single mode-independent title constant. Per-mode title fallbacks are a
/// zenpay_dart-specific addition, not a TypeScript SDK port.
abstract final class ZpUiDefaults {
  /// Checkout title used when the caller's `title` option is omitted or empty,
  /// for every mode except `ZpPluginMode.tokenise`.
  static const titleFallback = 'Process Payment';

  /// Checkout title used when the caller's `title` option is omitted or empty
  /// and `mode` is `ZpPluginMode.tokenise`.
  static const titleFallbackTokenise = 'Tokenize Card';

  /// Modal max-width hint (px). Matches TypeScript's `ZP_DEFAULTS.WIDTH_MODAL`
  /// — fixed, not mode-dependent, not caller-overridable. TypeScript documents
  /// this as informational only: a host rendering an iframe/modal is CSS-driven
  /// and may ignore it.
  static const maxWidth = '600px';

  /// Min-height hint (px) for `ZpPluginMode.tokenise`.
  static const heightTokenise = '450px';

  /// Min-height hint (px) for every other mode.
  static const heightDefault = '725px';
}
