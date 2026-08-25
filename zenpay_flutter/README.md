# zenpay_flutter

Flutter client SDK for ZenPay Hosted Checkout. Presents a checkout URL in a
platform-native browser surface (Chrome Custom Tabs on Android,
`SFSafariViewController` on iOS, a new tab on Web) and resolves with one
typed outcome once the customer comes back, dismisses it, or it times out.

It does **not** build checkout URLs, hold credentials, store state, or decide
whether a payment succeeded — that needs your ZenPay API key and a SHA3-512
fingerprint, so it belongs on your server: see
[`zenpay_dart`](../zenpay_dart/README.md). Nothing this package returns is
proof of payment; confirm that server-side, against ZenPay's signed callback.

Contributor/agent guidelines, including a per-file source map:
[CLAUDE.md](CLAUDE.md) (`AGENTS.md` here is a symlink to it).

---

## Install

```yaml
dependencies:
  zenpay_flutter: ^0.1.0
```

You also need a server that creates checkout URLs, and deep links configured
for whichever platforms you ship (an App Link intent filter on Android, an
associated domain on iOS). The return address must be HTTPS.

## Usage

```dart
import 'package:zenpay_flutter/zenpay_checkout.dart';

final checkout = ZpCheckout(
  configuration: ZpCheckoutConfiguration(
    allowedCheckoutHosts: {'pay.sandbox.travelpay.com.au'},
    expectedReturnUri: Uri.parse('https://app.merchant.com/checkout/return'),
  ),
  returnUriSource: createDefaultReturnUriSource(),
);

// On Web, reserve the surface synchronously inside the tap handler, before
// any `await`, or the browser blocks the tab.
if (!checkout.reserveLaunch()) return;

final Uri checkoutUrl;
try {
  checkoutUrl = await myBackend.createCheckout(amount: 42.00);
} on Object {
  checkout.releaseLaunchReservation();
  rethrow;
}

final outcome = await checkout.open(checkoutUrl: checkoutUrl);
```

`outcome` is a sealed `ZpCheckoutOutcome` — switch on it exhaustively
(`ZpReturnReceived`, `ZpPresentationDismissed`, `ZpTimedOut`,
`ZpLaunchFailed`) and confirm the payment against your backend rather than
inferring it from which case fired. One checkout may be in flight per
`ZpCheckout`; call `checkout.dispose()` when you're done with it.

On Web, call `completeWebCheckoutReturnIfPopup` as the first line of
`main()`, before `runApp` — see [CLAUDE.md](CLAUDE.md) for what it does and
why.

Every constructor parameter on `ZpCheckoutConfiguration` (timeout, length
bounds, UI toggles, the observer hook) is documented on the class itself —
see the API reference below for the current defaults; they're not repeated
here so this page can't go stale when one of them is retuned.

### Testing

`package:zenpay_flutter/testing.dart` exports `FakeReturnUriSource`, which
lets a test drive a checkout's return without any platform channel.

---

## More detail

- **Per-file source map, invariants, verification commands:** [CLAUDE.md](CLAUDE.md).
- **Full generated API reference** (every class, method, and parameter,
  always in sync with the published source): the "API reference" link on
  this package's [pub.dev](https://pub.dev/packages/zenpay_flutter) page.
- **Server-side SDK:** [`zenpay_dart`](../zenpay_dart/README.md).
- **Runnable end-to-end example:** [`example/`](../example/README.md) in
  [the repository](https://github.com/ianmenethil/zp-flutter).
- **Architecture, PCI posture, package inventory, and a full interactive
  walkthrough:** this repository's root `ARCHITECTURE.md`, `PCI_SAQ_A.md`,
  `PACKAGES.md`, and `zenpay-onboarding.html`.

## License

See [LICENSE](LICENSE).
