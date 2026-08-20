/// Entry point for the combined ZenPay example app.
library;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenpay_example_app/core/config/app_config.dart';
import 'package:zenpay_example_app/core/theme/theme.dart';
import 'package:zenpay_example_app/features/checkout/ui/checkout_page.dart';
import 'package:zenpay_example_app/firebase_options.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

const _appTitle = 'ZenPay Hosted Checkout';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Web, this page may be the checkout return popup rather than a real
  // app launch — see `completeWebCheckoutReturnIfPopup`'s doc comment. When
  // it is, the handoff to the original tab is already done and this window
  // is closing; there is nothing left to render.
  if (completeWebCheckoutReturnIfPopup(expectedReturnUri: appReturnUri)) {
    return;
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
  );

  runApp(const ZenPayExampleApp());
}

/// App shell: applies [ZenithTheme] and opens on [CheckoutPage].
final class ZenPayExampleApp extends StatelessWidget {
  /// Creates the app shell.
  const ZenPayExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      theme: ZenithTheme.light(),
      darkTheme: ZenithTheme.dark(),
      home: const CheckoutPage(),
    );
  }
}
