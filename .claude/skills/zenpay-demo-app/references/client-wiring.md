# Client wiring (`zenpay_flutter`)

Everything the Flutter half needs. The reference implementation is
`example/app/lib/features/checkout/ui/checkout_page.dart` — read it when something here is
ambiguous; it is the same code, running.

---

## Construct `ZpCheckout` once, in `initState`

```dart
_checkout = ZpCheckout(
  configuration: ZpCheckoutConfiguration(
    allowedCheckoutHosts: allowedCheckoutHosts,   // from .env
    expectedReturnUri: appReturnUri,              // platform-dependent, see below
    observer: ZpCheckoutObserver.from((e) => debugPrint('[ZpCheckout] $e')),
  ),
  returnUriSource: createDefaultReturnUriSource(),
);
```

Dispose it (`unawaited(_checkout.dispose())`) in `dispose()`. One instance per screen, not
one per tap — it enforces single-session concurrency and holds the return subscription.

The observer is optional but worth wiring in a demo: it is the only way to see a real
deep-link return distinguished from the resume-detection fallback. Exceptions thrown by an
observer are swallowed by the SDK, so it can never break checkout.

`expectedReturnUri` is compared **exactly** — scheme, host, port, path. A mismatch with the
backend's configured return URI is rejected, not ignored, and presents as "checkout timed
out" with nothing in the logs to explain it. Both `.env` files have to agree.

---

## The pay handler

Ordering is the whole game here. This is the shape:

```dart
Future<void> _pay() async {
  // 1. Validate synchronously. No awaits yet.
  if (!_valid()) return;

  // 2. Reserve the tab. MUST be before the first await.
  if (!_checkout.reserveLaunch()) {
    _show('Popup blocked', 'Allow popups for this site and try again.');
    return;
  }

  setState(() => _busy = true);
  try {
    // 3. Now async work is safe.
    final token = await prepareCheckout(backendBaseUrl, fields);
    final exchanged = await exchangeCheckout(backendBaseUrl, token);

    // 4. open() consumes the reservation.
    await _resolve(await _checkout.open(checkoutUrl: Uri.parse(exchanged.checkoutUrl)));
  } on Object catch (error) {
    // 5. Anything failing before open() would leak a blank tab.
    _checkout.releaseLaunchReservation();
    _show('Checkout failed', _explain(error));
  } finally {
    if (mounted) setState(() => _busy = false);
  }
}
```

**Why step 2 cannot move.** Browsers only honour `window.open` inside an unbroken user
gesture. The moment you `await` the backend call, the gesture is gone and the tab is blocked.
`reserveLaunch()` claims a blank tab while the gesture is still live; `open()` navigates it.
This costs nothing on mobile — it is a no-op there — so write it the same way on both
platforms rather than branching.

**Why step 5 exists.** The reservation is a real, open blank tab. If the backend call throws,
nothing consumes it and the customer is left staring at a blank window.

Every tap is a new, unrelated attempt with a fresh MUPID. There is no retry concept in this
SDK or backend — do not build one, and do not try to correlate attempts.

---

## Resolving the outcome

```dart
switch (outcome) {
  case ZpReturnReceived(:final returnUri):
    final t = returnUri.queryParameters['t'];
    if (t == null) { /* returned with no status token */ return; }
    final status = await fetchStatus(backendBaseUrl, t);
    // status.callbackVerified decides success — NOT the fact we got here.
  case ZpPresentationDismissed():
    // Closed before returning. Dismissal is NOT cancellation — it may still
    // have completed server-side. Say that, don't say "cancelled".
  case ZpTimedOut():
  case ZpLaunchFailed(:final code):
}
```

`ZpReturnReceived` means the customer's device came back to your app. That is all it means.
The redirect exists for UI/UX — it is a separate channel from the callback that carries the
actual status, not an earlier step in the same flow. The SDK hands back the return URI as it
arrived; reading the query is your job, not the SDK's, and the backend is what turns a token
into a status.

If you show a green tick on `ZpReturnReceived` alone, the demo will show "paid" for a
customer who abandoned checkout and hit back. That is the bug this whole section exists to
prevent.

### Expect the first lookup to be unverified

The two channels are independent, so the customer can be back in your app before the webhook
has landed. `callbackVerified: false` on the first fetch is an ordinary state, not an error.

Show "processing" and poll a few times — a short backoff, a hard cap, then stop:

```dart
for (var attempt = 0; attempt < 5; attempt++) {
  final status = await fetchStatus(backendBaseUrl, t);
  if (status.callbackVerified) return _showVerified(status);
  await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
}
_showStillProcessing(); // honest: we do not know yet
```

Make the transition visible on screen — "awaiting signed callback" resolving to "verified" is
the clearest way a demo can teach the provisional-vs-authoritative distinction instead of
merely obeying it. Never let the loop resolve to "paid" on timeout: not knowing is a real
outcome, and a demo that fakes certainty teaches the exact habit this SDK is built to prevent.

### Show every verified outcome distinctly

A verified callback is not the same as a successful payment. `StatusResponse` already carries
what you need — give each state its own treatment rather than collapsing everything that
isn't `successful` into one "failed" screen:

| `status` | Wire | Show |
|---|---|---|
| `successful` | `3` | the reference (`paymentReference` / `preauthReference` / `tokenReference`, per mode) |
| `failed` | `4` | `failureCode` and `failureReason` verbatim — they are the whole reason the fields exist |
| `cancelled` | `5` | the customer chose to stop; not an error |
| `error` | `1`, `6` | something went wrong at ZenPay's end, distinct from the customer failing a payment |
| `pending` | `0`, `7` | verified, but ZenPay is still working — keep polling or say so |

Then render the raw `callbackPayload` — the whole verified `{response, validationCode}` body
— in a collapsible panel, the way `example/app` does. A real merchant app would never show a
customer that, and that is exactly why a demo should: the person running it is trying to
learn what the callback actually contains, and a screenshot of the real payload teaches more
than any amount of prose here.

---

## Mobile first

The default presenter opens Android Custom Tabs / iOS `SFSafariViewController`. Nothing extra
to write.

- Return arrives as an App Link / Universal Link via `package:app_links`.
- `APP_RETURN_URI_MOBILE` must be a **public HTTPS host** serving `/.well-known/`, not
  `localhost` — the OS fetches those files from the internet to verify the link. Use
  `dart run cli.dart --quick-tunnel`.
- Native config is patched by `scripts/apply_platform_config.dart`, which `cli.dart --server`
  runs automatically whenever `PUBLIC_BASE_URL` changes. Do not hand-edit `AndroidManifest.xml`
  or `Runner.entitlements` — `flutter create` regenerates them.
- There is no native dismissal callback on Android. The SDK infers dismissal from app-resume
  plus a 500 ms grace period, so a returning deep link wins the race. Occasionally seeing
  `ZpPresentationDismissed` right before a return is the mechanism working, not a bug.

## Web second

Web is a small diff on top of the mobile app, not a separate implementation. Three additions:

1. **First line of `main()`**, before anything else:
   ```dart
   if (completeWebCheckoutReturnIfPopup(expectedReturnUri: appReturnUri)) return;
   ```
   Checkout opens in a second tab; that tab has to relay the return back to the opener and
   close itself. When this returns `true`, the window *is* that popup — return immediately and
   render nothing.
2. **`reserveLaunch()` ordering** — already in the pay handler above. This is where it matters.
3. **`APP_RETURN_URI_WEB` must be `https`.** `cli.dart --web` serves over TLS using the mkcert
   cert from `--bootstrap`; without it you get plain HTTP and the return is rejected.

---

## Configuration

Read with `--dart-define-from-file=.env` (the scaffold wires this into the run command):

| Variable | Purpose |
|---|---|
| `BACKEND_BASE_URL` | your demo backend's origin |
| `ALLOWED_CHECKOUT_HOSTS` | must match the backend's `ZENPAY_ALLOWED_CHECKOUT_HOSTS` |
| `APP_RETURN_URI_WEB` | https origin the web build returns to |
| `APP_RETURN_URI_MOBILE` | public https App Link URL |

Pick `appReturnUri` by platform with `kIsWeb`, mirroring the backend's own choice — see
`example/app/lib/core/config/app_config.dart`.

**Never import `package:zenpay_dart` here.** It handles the merchant password and HMAC
secret. In a Flutter app those ship to the customer's device.
