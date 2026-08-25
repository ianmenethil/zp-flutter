# PCI DSS SAQ A — Presentation Surfaces Compared

How each of this SDK's two checkout-presentation surfaces — the default (Android Custom Tabs
/ iOS `SFSafariViewController` / a new browser tab, via `zenpay_flutter`) and the optional
addition (an in-app WebView, via `zenpay_embedded`) — relates to PCI DSS SAQ A. Neither
surface is described in isolation: the point of this document is the comparison, and why the
system-browser surface is the default rather than merely the first one shipped.

**This document does not determine SAQ eligibility for anyone.** It describes what each
presentation surface does and enforces. Actual SAQ eligibility depends on the merchant's
complete environment, payment integration, provider status, and acquirer/payment-brand
rules, and must be confirmed with the merchant's own acquirer and/or QSA (Qualified Security
Assessor) — see § 4.

---

## 1. Why Custom Tabs / `SFSafariViewController` Is the Default

Both surfaces present the exact same ZenPay hosted page, over the exact same HTTPS URL, with
the exact same server-side verification behind it (§ 2 covers what stays identical). The
difference that matters here is architectural, not behavioral:

- **There is no WebView object for the app to hold.** Android Custom Tabs and iOS
  `SFSafariViewController` render the hosted page inside the operating system's own browser
  process (Chrome / Safari) — a fully separate process from the app's. The app never has a
  handle to that page's document, its JavaScript context, or its navigation. Every risk in
  § 3 below (a JavaScript bridge, a caller-controlled navigation delegate, a sub-frame
  sharing a document with merchant script) requires a WebView object to exist in the first
  place. Here, none does — the risk isn't mitigated, it's structurally absent.
- **3DS and wallet flows work with zero extra integration effort.** Card-issuer 3DS
  challenges and wallet payment methods (Apple Pay, Google Pay) are things a full, unrestricted
  browser already handles. Nothing needs a platform capability flag, a manifest entry, or a
  Payment Request API opt-in — those requirements are specific to embedding a WebView (§ 3.6)
  and simply don't arise here.
- **Indistinguishable from the customer opening the URL themselves.** From ZenPay's hosted
  page's perspective, and from the platform's perspective, this is an ordinary browser tab
  visiting an ordinary HTTPS URL. There is no reduced-capability, app-embedded execution
  environment for anything to reason about or restrict.
- **Return handling and trust model are otherwise identical to embedded** (see § 2) — the
  outcome is still provisional, still verified server-side. Choosing the system browser costs
  nothing on that front; it only removes an entire category of risk on the presentation side.

This is why `zenpay_flutter`'s Custom Tabs/Safari presenter is the default *and* the
recommended choice, not just the one implemented first: it is the simplest possible answer to
"does this app's own code ever touch the payment page," and the answer is architecturally no.

---

## 2. What Stays Identical Either Way

Regardless of which presenter is supplied to `ZpCheckout` (see `ARCHITECTURE.md` § 3 for the
`CheckoutPresenter` contract both implement):

- The merchant backend builds the launch URL via `zenpay_dart`; credentials and hashing never
  leave the backend.
- `ZpCheckoutConfiguration`, `ZpCheckoutOutcome`, launch URL validation
  (`isAllowedCheckoutUrl`), and return URI validation (`ZpReturnValidator`) are unchanged.
- Every returned outcome is **provisional only**. Final payment status is confirmed
  exclusively via the backend's own signed-webhook verification (`verifyZpCallback`,
  constant-time `ValidationCode` comparison) — never from a browser redirect or a WebView
  navigation event, in either mode.
- The merchant application never handles card data directly in either mode. Card entry
  happens entirely within ZenPay's own hosted page.

What changes between the two modes is described in § 3.

---

## 3. The Embedded WebView — What Changes, and What Breaks SAQ-A If Misused

`zenpay_embedded` is an explicit opt-in (see `ARCHITECTURE.md` § 3) for merchants who need an
in-app, modal presentation instead of switching to a system browser surface. Choosing it does
not, by itself, move an integration in or out of PCI scope — the hosted page renders in the
same rendering engine either way. What changes is that **a WebView object now exists inside
the app's own process**, which means the app's code is capable of exposing an attack surface
to that hosted page that simply had nothing to attach to in § 1's world. Whether that
capability is exercised is the entire question this section answers.

Each item below is a mistake that would break SAQ-A-consistent behavior, why it matters, and
what `zenpay_embedded` does instead — enforced in code, not just documented, where a grep
gate can meaningfully catch a regression (§ 5).

### 3.1 Adding a JavaScript bridge to the hosted page

`addJavaScriptChannel`/`setOnConsoleMessage` would let native code exchange data with the
hosted page's JavaScript. On iOS, `webview_flutter` registers a channel's handler at the
`WKWebViewConfiguration` level regardless of any frame-scoping flag — reachable from *every*
frame the hosted page loads, including third-party 3DS/ACS frames, with no supported way to
scope it narrower. There is no safe way to add one; the only safe state is never adding one.
**Barred by the `no-js-bridge` lefthook gate**, anywhere in `zenpay_embedded/lib/`.

### 3.2 Accepting a caller-supplied `WebViewController`

A JS channel already attached to a controller cannot be removed without knowing its name — so
accepting an externally-built controller would let a caller carry a bridge past the check in
§ 3.1 without it ever appearing in this package's own source. `ZenPayCheckoutWebView`
(`zenpay_embedded/lib/src/render_checkout_web_view.dart`) builds its own controller and
accepts no caller-supplied one — structurally, not by convention.

### 3.3 Allowlisting WebView navigation by host

A 3DS challenge sends the customer to their own card issuer's ACS host, which cannot be
enumerated in advance — filtering navigation by the checkout-URL host allowlist would break
authentication mid-payment. `decide_web_view_navigation.dart`'s `decideNavigation` restricts
navigation to `https` only, never a host allowlist. That allowlist keeps its existing,
separate job: validating the checkout URL itself *before* launch (`isAllowedCheckoutUrl`, in
`zenpay_flutter`) — not filtering what the hosted page itself may navigate to afterward.
**Guarded by the `webview-no-host-allowlist` lefthook check.**

### 3.4 Embedding the checkout as a sub-frame next to merchant script

The WebView's top-level document must always be the ZenPay hosted page itself. A merchant
page with the checkout embedded as an iframe *alongside merchant-authored script* is a
materially different, riskier architecture — merchant script and the PSP's frame sharing one
document is exactly the pattern that typically moves an integration from SAQ A to the far
heavier SAQ A-EP. This package only ever performs full top-level navigation; that
sub-frame architecture does not occur anywhere in it.

### 3.5 Leaving browsing state behind after dismiss

A dismissed checkout that leaves cookies, cache, or local storage behind is a live payment
session's state surviving in shared, app-wide storage (`webview_flutter` exposes no
per-instance browsing-data store on either platform, so any leftover state is reachable by
any other WebView in the host app). On dismiss, `zenpay_embedded` navigates to `about:blank`,
then clears cache, local storage, and cookies, in that order. **Guarded by the
`webview-teardown` lefthook check.**

### 3.6 Google Pay: a separate, non-PCI requirement that still breaks the wallet flow if missed

Unlike § 3.1–3.5, this isn't a PCI control — it's a platform restriction that specifically
affects embedded WebViews. Google Pay's button and payment logic run entirely *inside* the
ZenPay hosted page's own JavaScript, not in any code this SDK or the host app owns — but that
JavaScript still executes inside a WebView running in the host app's own process, and Android
gates the WebView's use of the standard Payment Request API behind a native `WebSettings` flag.
`zenpay_embedded` opts in via `AndroidWebViewController`'s `WebViewFeatureType.paymentRequest`
(`_enableGooglePayPaymentRequest()`, a `WebSettings`-level toggle, not a JavaScript channel — it
carries none of the § 3.1 bridge risk).

**Verified load-bearing by a live device test** (Pixel 9 Pro XL, embedded-WebView demo,
2026-08-25): commenting out `_enableGooglePayPaymentRequest()` and rebuilding reproduces
Google's own in-page failure verbatim:

> Something went wrong
> Google Pay couldn't load properly because this App uses a WebView. App developers must
> follow the instructions to enable Google Pay to work within Android WebView:
> https://goo.gle/gpay-android-webview-help [OR_BIBED_15] OR_BIBED_15

With the flag restored, Google Pay has worked across every checkout mode in extensive
real-device testing.

**Correction to a prior claim in this section:** an earlier version of this doc additionally
claimed the host app's `AndroidManifest.xml` must declare `<queries>` entries
(`org.chromium.intent.action.PAY`, `IS_READY_TO_PAY`, `UPDATE_PAYMENT_DETAILS`) for Google Pay
to work. That claim was never verified against code and is contradicted by testing:
`example/app/android/app/src/main/AndroidManifest.xml` declares no such entries (only the
Flutter-generated `PROCESS_TEXT` query), and Google Pay has still worked reliably across
repeated real-device tests. Treat that specific manifest requirement as unconfirmed rather
than a known gap — if your own target devices/Play Services versions need it, verify
independently; don't assume this doc's earlier claim was correct.

---

## 4. What Neither Mode Decides

Every control above describes what the code does and enforces. None of it is a PCI
determination. Two specifics worth stating explicitly (from this repo's earlier PCI research,
still true under PCI DSS v4.0.1):

- **SAQ A merchants can still carry ASV (Approved Scanning Vendor) scanning
  responsibilities** for their own e-commerce webpages, including redirect integrations —
  SAQ A eligibility does not exempt the merchant's own site from external vulnerability
  scanning obligations.
- **Embedded payment forms carry additional script-security eligibility considerations**
  beyond a plain redirect integration. `zenpay_embedded` is, architecturally, an embedded
  payment form presentation — § 3's controls are exactly what address this, but the
  eligibility determination itself still sits with the merchant's acquirer/QSA, not with this
  document or this package.

### Outstanding compliance gates — process, not code

Separately from the code controls in § 3, and **still required before `zenpay_embedded` is
advertised to merchants** as SAQ-A-compatible:

- ZenPay product approval for the embedded presentation mode.
- 3DS certification.
- A tested wallet / alternative-payment-method matrix (Apple Pay, Google Pay, PayTo, PayID,
  bank account, and every other method the checkout supports).
- External-app switching tests (e.g. a 3DS or wallet flow that hands off to another app and
  back).
- Cookie/storage tests on physical devices, not just emulators.
- Accessibility testing.
- QSA review.

No code change closes any of these — they are evidence/approval gates, tracked separately
from this document.

---

## 5. Regression Guards

Three of § 3's controls are backed by a `lefthook` pre-commit check that fails the commit
outright if the control is ever silently removed — not just written down here:

| Control | `lefthook.yml` command |
| :--- | :--- |
| No JS bridge (§ 3.1) | `no-js-bridge` — fails if `addJavaScriptChannel`/`setOnConsoleMessage` appear anywhere in `zenpay_embedded/lib` |
| Full teardown on dismiss (§ 3.5) | `webview-teardown` — fails unless `render_checkout_web_view.dart` still calls `clearCache`, `clearLocalStorage`, and `WebViewCookieManager` |
| HTTPS-only / no host allowlist on navigation (§ 3.3) | `webview-no-host-allowlist` — fails if `decide_web_view_navigation.dart` ever references the checkout-URL host allowlist (`isAllowedCheckoutUrl`/`allowedCheckoutHosts`) |

§ 3.2, 3.4, and 3.6 are structural (no caller-supplied `WebViewController` parameter exists to
pass one; full-navigation-only and the Google Pay flag are single call sites) rather than
"forbidden pattern" checks, so a grep gate adds little for those — a code reviewer reading the
diff is the check.

---

## Related Guides

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — the full integration diagram and how the two
  presenters share one `CheckoutPresenter` contract.
- **[README.md](README.md)** — repo overview, quick start, package index.
- **[zenpay_flutter/README.md](zenpay_flutter/README.md)** — the default presenter's usage docs.
- **[zenpay_embedded/README.md](zenpay_embedded/README.md)** — the embedded presenter's usage docs.
- **[CLAUDE.md](CLAUDE.md)** — contributor/agent guidelines, monorepo tooling.
