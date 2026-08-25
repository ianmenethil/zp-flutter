# zenpay_flutter

Secure Flutter orchestration for ZenPay Hosted Checkout sessions.

Opens a checkout URL in a platform-native browser surface, waits for the
customer to come back, and resolves with one typed outcome.

## What this package does, and does not, do

It presents a URL and reports what happened. That is the whole job.

It does **not** build checkout URLs, hold credentials, store state, or decide
whether a payment succeeded. Building the URL needs your ZenPay API key and a
SHA3-512 fingerprint, so it belongs on your server — see `zenpay_dart`. Nothing
this package returns is proof of payment; confirm that server-side, against
ZenPay's signed callback.

## Features

- **Native browser surfaces** — Chrome Custom Tabs on Android,
  `SFSafariViewController` on iOS, both via `url_launcher`. On Web, a new tab
  with synchronous reservation so popup blockers do not eat the launch.
- **Strict launch validation** — the checkout URL must be HTTPS on port 443,
  under 4096 characters, free of credentials and fragments, and on a host you
  allowlisted. Anything else throws before a browser opens.
- **Strict return validation** — an incoming return (an App Link or Universal
  Link on mobile, or a same-origin `postMessage` handoff from the return
  popup on Web) must match your configured return address exactly (scheme,
  host, port, path) and respect length bounds, or it is ignored.
- **No hidden I/O** — the package makes no network calls, writes no logs, and
  persists nothing. `ZpCheckoutObserver` is the only way to see inside it.

## Getting started

```yaml
dependencies:
  zenpay_flutter: ^0.1.0
```

You also need a server that creates checkout URLs. Deep links must be
configured for the platforms you ship: an App Link intent filter on Android, an
associated domain on iOS. Your return address must be HTTPS.

On Web, call `completeWebCheckoutReturnIfPopup` as the first line of `main()`,
before `runApp`. It returns `true` (and `main()` should stop there, not call
`runApp`) when this page was loaded as the same-origin checkout return popup —
it relays the return to the opener via `postMessage` and closes the popup:

```dart
void main() {
  if (completeWebCheckoutReturnIfPopup(
    expectedReturnUri: Uri.parse('https://app.merchant.com/checkout/return'),
  )) {
    return;
  }
  runApp(const MyApp());
}
```

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
```

`createDefaultReturnUriSource` picks the right source for the platform you're
compiling for: `AppLinksReturnUriSource` (App Links / Universal Links) on
Android and iOS, or a listener for the popup handoff above on Web.

On Web, reserve the surface synchronously inside the tap handler, before any
`await`, or the browser will block the tab:

```dart
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

Handle the outcome. The switch is exhaustive — `ZpCheckoutOutcome` is sealed:

```dart
switch (outcome) {
  case ZpReturnReceived(:final returnUri):
    // The customer came back. This is NOT proof of payment.
    // returnUri keeps whatever query your server put on the return address —
    // read what you need and confirm the payment on your backend.
    await myBackend.confirm(returnUri.queryParameters);

  case ZpPresentationDismissed():
    // Browser closed before returning. The payment may still have gone
    // through, so check with your backend rather than assuming it failed.
    await myBackend.reconcile();

  case ZpTimedOut():
    // Nothing happened within ZpCheckoutConfiguration.timeout (default 20 min).
    await myBackend.reconcile();

  case ZpLaunchFailed(:final code):
    // No browser opened, so nothing was charged.
    showError('Could not open checkout: $code');
}

await checkout.dispose();
```

One checkout may be in flight per `ZpCheckout`. Calling `open` while another is
active throws `ZpCheckoutAlreadyActiveException`.

### Configuration

| Parameter | Default | Purpose |
|---|---|---|
| `allowedCheckoutHosts` | required | Hosts a checkout URL may point at. |
| `expectedReturnUri` | required | Clean HTTPS URI; no query or fragment. |
| `timeout` | 20 minutes | How long to wait before giving up. |
| `showBrowserTitle` | `true` | Show the browser toolbar title, where supported. |
| `allowExternalBrowserFallback` | `true` | Fall back to the system browser. |
| `maxReturnUriLength` | 2048 | Reject longer return URIs. |
| `maxReturnValueLength` | 512 | Reject longer individual query values. |
| `observer` | `null` | Sink for `ZpCheckoutEvent`s. |

### Observability

The SDK logs nothing. Supply an observer to see inside a checkout — most useful
for rejected returns, which are otherwise silent:

```dart
final class LoggingObserver implements ZpCheckoutObserver {
  @override
  void onEvent(ZpCheckoutEvent event) => debugPrint('$event');
}
```

Events carry no full checkout URL and no raw return query, so forwarding one to
a log sink cannot leak the credentials in a checkout URL. Exceptions thrown from
`onEvent` are swallowed and cannot affect the checkout.

### Testing

`package:zenpay_flutter/testing.dart` provides `FakeReturnUriSource`, which lets
a test emit a return URI without any platform channel.

**Coverage:** 89.1% line coverage. Regenerate with `melos run coverage --scope=zenpay_flutter` from the repository root — writes `zenpay_flutter/coverage/lcov.info`.

## Additional information

- Server-side URL building, fingerprints, and callback verification:
  [`zenpay_dart`](../zenpay_dart/README.md).
- A runnable Flutter app plus reference backend:
  [`example/`](../example/README.md) in
  [the repository](https://github.com/ianmenethil/zp-flutter).
- Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md).
