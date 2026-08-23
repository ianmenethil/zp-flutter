/// Checkout screen — the demo flow end to end.
///
/// Creates a session against the example backend, presents hosted checkout via
/// `zenpay_flutter`, waits for the return link, then asks the backend for the
/// authoritative result.
///
/// The ordering in `_pay` is load-bearing: `reserveLaunch()` runs synchronously
/// before the first `await`, because a browser only honours `window.open`
/// inside an unbroken user gesture. Reversed, it works on mobile and is
/// silently blocked on web.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zenpay_example_app/core/config/app_config.dart';
import 'package:zenpay_example_app/features/checkout/models/checkout_modes.dart';
import 'package:zenpay_example_app/features/checkout/models/mock_customer.dart';
import 'package:zenpay_example_app/features/checkout/services/checkout_service.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_amount_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_environment_banner.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_labeled_field.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_pay_button.dart';
import 'package:zenpay_example_app/features/checkout/ui/widgets/zenpay_selectable_card.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

const _appBarTitle = 'ZenPay Hosted Checkout';
const _errPopupBlockedTitle = 'Could not open checkout';
const _errPopupBlockedDetail = 'Popup blocked. Allow popups and retry.';
const _errCheckoutFailedTitle = 'Checkout failed';
const _errSessionConfigRequired = 'SESSION_CONFIGURATION_REQUIRED';
const _errMissingCredentialsHelp = 'The backend has no ZenPay credentials — fill in backend/.env.';
const _noPaymentYetText = 'No payment attempt yet.';
const _errBackendUnreachable = "Can't reach the backend — is it running?";
const _errInvalidEmail = 'Enter a valid email address';
const _errInvalidPhone = 'Enter a valid phone number';

/// Same shape the backend requires (`server_app.dart`'s `_emailPattern`) —
/// kept in sync so the client rejects what the server would anyway.
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Digits plus common separators (`+`, spaces, hyphens, parens); 6–15 digits.
final _phoneAllowedCharsPattern = RegExp(r'^[0-9 ()+-]+$');
final _phoneDigitPattern = RegExp('[0-9]');

/// Blank is fine — [_CheckoutPageState._pay] falls back to a placeholder value for
/// an empty field. Only rejects text that was actually typed and is bad.
String? _validateEmail(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;
  return _emailPattern.hasMatch(value) ? null : _errInvalidEmail;
}

/// See [_validateEmail] — same blank-is-fine rule.
String? _validatePhone(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;
  final digitCount = _phoneDigitPattern.allMatches(value).length;
  final valid = _phoneAllowedCharsPattern.hasMatch(value) && digitCount >= 6 && digitCount <= 15;
  return valid ? null : _errInvalidPhone;
}

/// Home screen: transaction-mode picker, customer fields, and a reserved
/// results slot — everything the real checkout flow will attach to.
final class CheckoutPage extends StatefulWidget {
  /// Creates the checkout page.
  ///
  /// [presenter] and [returnUriSource] are both optional and null by
  /// default, which reproduces today's behavior exactly: `ZpCheckout` falls
  /// back to its default Custom Tabs/`SFSafariViewController` presenter and
  /// `createDefaultReturnUriSource()`. Supplying both together (e.g. an
  /// `EmbeddedCheckoutPresenter` and its `returnUriSource` from
  /// `package:zenpay_embedded`) swaps only how checkout is presented —
  /// nothing else on this page changes.
  const CheckoutPage({super.key, this.presenter, this.returnUriSource});

  /// Overrides the default checkout presentation surface.
  final CheckoutPresenter? presenter;

  /// Overrides the default return URI source. Must be supplied together
  /// with [presenter] when the presenter has its own (e.g. embedded mode's
  /// `WebViewReturnUriSource`) — see the constructor doc.
  final ZpReturnUriSource? returnUriSource;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

/// Local form/selection state for [CheckoutPage]. Owns no HTTP or SDK state.
class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  late final ({String name, String email, String reference, String phone}) _placeholder;
  late final double _placeholderAmount;

  TransactionMode _mode = TransactionMode.makePayment;
  String? _emailError;
  String? _phoneError;

  late final ZpCheckout _checkout;
  bool _busy = false;
  ({
    String title,
    String detail,
    bool isError,
    bool isVerified,
    Map<String, Object?>? callbackPayload,
  })?
  _result;

  @override
  void initState() {
    super.initState();
    _placeholder = randomCustomer();
    _placeholderAmount = randomAmount();
    _checkout = ZpCheckout(
      configuration: ZpCheckoutConfiguration(
        allowedCheckoutHosts: allowedCheckoutHosts,
        expectedReturnUri: appReturnUri,
      ),
      returnUriSource: widget.returnUriSource ?? createDefaultReturnUriSource(),
      presenter: widget.presenter,
    );
  }

  /// Reserve, prepare, exchange, present, resolve. Every tap is an
  /// unrelated new ZenPay checkout attempt with a fresh MUPID — there is no
  /// app-level concept of retrying a prior attempt.
  Future<void> _pay() async {
    final emailError = _validateEmail(_email.text);
    final phoneError = _validatePhone(_phone.text);
    if (mounted) {
      setState(() {
        _emailError = emailError;
        _phoneError = phoneError;
      });
    }
    if (emailError != null || phoneError != null) return;

    // Must precede every await — see the library doc.
    if (!_checkout.reserveLaunch()) {
      _show(_errPopupBlockedTitle, _errPopupBlockedDetail);

      return;
    }
    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      String? recaptchaToken;
      final client = recaptchaClient;
      if (client != null) {
        try {
          recaptchaToken = await client.execute('checkout');
          if (recaptchaToken.isEmpty) recaptchaToken = null;
        } on Object catch (e, st) {
          debugPrint('reCAPTCHA failed to get token: $e\n$st');
        }
      }

      final checkoutToken = await prepareCheckout(
        backendBaseUrl,
        <String, Object?>{
          'customerName': _text(_name, _placeholder.name),
          'customerEmail': _text(_email, _placeholder.email),
          'customerReference': _text(_reference, _placeholder.reference),
          'contactNumber': _text(_phone, _placeholder.phone),
          'mode': _mode.wireValue,
          if (_mode.usesAmount) 'paymentAmount': double.tryParse(_amount.text.trim()) ?? _placeholderAmount,
        },
        recaptchaToken: recaptchaToken,
      );
      final exchanged = await exchangeCheckout(
        backendBaseUrl,
        checkoutToken,
      );

      await _resolve(
        await _checkout.open(checkoutUrl: Uri.parse(exchanged.checkoutUrl)),
      );
    } on Object catch (error) {
      // open() consumes the reservation; anything failing before it would
      // otherwise leak a blank tab.
      _checkout.releaseLaunchReservation();
      _show(_errCheckoutFailedTitle, _explain(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Maps an outcome to a result, confirming a return against the backend.
  Future<void> _resolve(ZpCheckoutOutcome outcome) async {
    switch (outcome) {
      case ZpReturnReceived(:final returnUri):
        // The SDK hands back the return URI as it arrived. Reading what the
        // backend put in the query is this app's job, not the SDK's.
        final token = returnUri.queryParameters['t'];
        if (token == null) {
          _show(
            'Payment status unknown',
            'The return carried no status token.',
          );
          return;
        }

        // Returning proves the customer came back, not that they paid — only
        // the signature-verified callback the backend holds decides that.
        final status = await fetchStatus(backendBaseUrl, token);
        final verified = status.callbackVerified;
        _show(
          'Payment ${status.status}',
          verified ? 'Verified by signed ZenPay callback.' : 'Provisional — awaiting the signed callback.',
          isError: !verified,
          isVerified: verified,
          callbackPayload: status.callbackPayload,
        );
      case ZpPresentationDismissed():
        _show(
          'Checkout dismissed',
          'Closed before returning. Dismissal is not cancellation — it may '
              'still complete server-side.',
        );
      case ZpTimedOut():
        _show('Checkout timed out', 'No return arrived in time.');
      case ZpLaunchFailed(:final code):
        _show(_errPopupBlockedTitle, 'Launch failed: ${code.name}.');
    }
  }

  /// Turns the most common demo failure into an actionable message.
  String _explain(Object error) => switch (error) {
    BackendError(:final code) when code == _errSessionConfigRequired => _errMissingCredentialsHelp,
    http.ClientException() => _errBackendUnreachable,
    _ => '$error',
  };

  String _text(TextEditingController controller, String fallback) => controller.text.trim().isEmpty ? fallback : controller.text.trim();

  void _show(
    String title,
    String detail, {
    bool isError = true,
    bool isVerified = false,
    Map<String, Object?>? callbackPayload,
  }) {
    if (mounted) {
      setState(() {
        _result = (
          title: title,
          detail: detail,
          isError: isError,
          isVerified: isVerified,
          callbackPayload: callbackPayload,
        );
      });
    }
  }

  @override
  void dispose() {
    unawaited(_checkout.dispose());
    _name.dispose();
    _email.dispose();
    _reference.dispose();
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Make Payment / Tokenise / Custom Payment / Pre-Auth picker cards.
  List<Widget> _buildTransactionModeSection(BuildContext context) {
    Widget card(TransactionMode mode) => ZenPaySelectableCard(
      icon: mode.icon,
      label: mode.label,
      subtitle: mode.subtitle,
      selected: mode == _mode,
      onTap: () => setState(() => _mode = mode),
    );

    return <Widget>[
      const Text(
        'Transaction mode:',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 8),
      Row(
        children: <Widget>[
          Expanded(child: card(TransactionMode.makePayment)),
          const SizedBox(width: 12),
          Expanded(child: card(TransactionMode.tokenise)),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Expanded(child: card(TransactionMode.customPayment)),
          const SizedBox(width: 12),
          Expanded(child: card(TransactionMode.preauthorization)),
        ],
      ),
    ];
  }

  /// Name/email/reference/phone input fields.
  List<Widget> _buildCustomerFields() {
    return <Widget>[
      ZenPayLabeledField(
        controller: _name,
        label: 'Customer name',
        hintText: _placeholder.name,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      ZenPayLabeledField(
        controller: _email,
        label: 'Customer email',
        hintText: _placeholder.email,
        keyboardType: TextInputType.emailAddress,
        errorText: _emailError,
        onChanged: (_) {
          if (_emailError != null) setState(() => _emailError = null);
        },
      ),
      const SizedBox(height: 12),
      ZenPayLabeledField(
        controller: _reference,
        label: 'Customer reference',
        hintText: _placeholder.reference,
      ),
      const SizedBox(height: 12),
      ZenPayLabeledField(
        controller: _phone,
        label: 'Phone number',
        hintText: _placeholder.phone,
        keyboardType: TextInputType.phone,
        errorText: _phoneError,
        onChanged: (_) {
          if (_phoneError != null) setState(() => _phoneError = null);
        },
      ),
    ];
  }

  /// The payment outcome, or a placeholder before the first attempt.
  /// Green for a verified callback — distinct from [ColorScheme.primary],
  /// which the brand theme uses for CTAs, not a success signal.
  Color _verifiedColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? Colors.green.shade400 : Colors.green.shade700;

  Widget _buildResults(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = _result;
    final color = result == null
        ? colors.onSurfaceVariant
        : result.isVerified
        ? _verifiedColor(context)
        : result.isError
        ? colors.error
        : colors.primary;
    final payload = result?.callbackPayload;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              result == null
                  ? Icons.hourglass_empty
                  : result.isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    result?.title ?? _noPaymentYetText,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                  if (result != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      result.detail,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                  if (payload != null && payload.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    _buildCallbackPayloadPanel(context, payload),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Collapsible panel showing the entire verified callback body ZenPay
  /// posted — `{response, validationCode}` — exactly as the backend
  /// forwarded it, unfiltered.
  Widget _buildCallbackPayloadPanel(
    BuildContext context,
    Map<String, Object?> payload,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          'Raw callback payload',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurfaceVariant,
          ),
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(payload),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// App bar title: brand logo (swapped for the theme's brightness) next to
  /// the app name, matching `samples/app`'s header.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            Theme.of(context).brightness == Brightness.dark ? 'assets/brand/logo-light.png' : 'assets/brand/logo.png',
            height: 28,
          ),
          const SizedBox(width: 14),
          const Flexible(
            child: Text(_appBarTitle, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: <Widget>[
          ZenPayEnvironmentBanner(allowedCheckoutHosts: allowedCheckoutHosts),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                ..._buildTransactionModeSection(context),
                if (_mode.usesAmount) ...<Widget>[
                  const SizedBox(height: 16),
                  ZenPayAmountField(
                    controller: _amount,
                    hintText: _placeholderAmount.toStringAsFixed(2),
                    presets: _mode.amountPresets,
                  ),
                ],
                const SizedBox(height: 16),
                ..._buildCustomerFields(),
                const SizedBox(height: 20),
                ZenPayPayButton(onPressed: _busy ? null : _pay, isBusy: _busy),
                const SizedBox(height: 20),
                _buildResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
