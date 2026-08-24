# Integration contract

The wire format between a merchant app and a merchant backend, as implemented in
`example/backend/lib/src/server_app.dart` and consumed by
`example/app/lib/features/checkout/services/checkout_service.dart`. A generated demo should
match this shape — not because the shape is sacred, but because the reference app, the
reference backend, and every doc in this repo already agree on it.

`/v2/sessions` does not exist. If you find it in an older doc or a stale memory, it is dead —
the flow is two-step token → exchange.

---

## The three calls

### 1. `POST /api/v1/checkout/token` → `201`

Prepares an attempt and returns a signed, short-lived capability. No ZenPay URL is built yet.

**Headers**

| Header | Value | Notes |
|---|---|---|
| `content-type` | `application/json` | |
| `idempotency-key` | 16–128 chars, unique per tap | Required. HTTP-level duplicate protection — a *different* concern from the MUPID, do not merge them |
| `x-client` | `web` or `mobile` | Only these two. Decides the return URI the backend picks, and whether reCAPTCHA applies |
| `x-recaptcha-token` | assessment token | Web only, and only when reCAPTCHA is configured |
| `x-request-id` | any correlating id | Optional; the backend echoes it and logs one merged `http_trace` line |

**Body** — order and customer data. The reference sends:

```json
{
  "customerName": "...",
  "customerEmail": "...",
  "customerReference": "...",
  "contactNumber": "...",
  "mode": 0,
  "paymentAmount": 12.50
}
```

The backend resolves the trusted amount itself and mints the MUPID and ZenPay timestamp —
the client never supplies those. Replaying the same `idempotency-key` re-mints a token for
the *same* attempt; changing the order fields under a reused key is a `409
IDEMPOTENCY_KEY_REUSED`.

**Response** — `{"checkoutToken": "<signed token>"}`

### 2. `POST /api/v1/checkout/exchange` → `200`

Exchanges the capability for the ZenPay launch URL.

**Headers** — `authorization: Bearer <checkoutToken>`, optional `x-request-id`. No body.

**Response** — `{"checkoutUrl": "https://pay.sandbox.travelpay.com.au/..."}`

Safe to call more than once: a replayed token resolves to the same attempt and returns the
already-built URL, never a new one.

### 3. `GET /api/v1/sessions?t=<token>` → `200`

The backend's authoritative status. `t` is the signed token the return URI carried — no
caller-supplied id is ever trusted, so there is no "look up attempt 123" endpoint to write.

**Response**

```json
{
  "status": "successful",
  "callbackVerified": true,
  "paymentReference": "...",
  "preauthReference": null,
  "tokenReference": null,
  "failureCode": null,
  "failureReason": null,
  "zenPayStatusCode": 3,
  "callbackPayload": { "response": {}, "validationCode": "..." }
}
```

`callbackVerified` is the field that matters. `true` means ZenPay's signed webhook arrived
and its `ValidationCode` passed a constant-time SHA3-512 check. `false` means the customer
came back but nothing has proven a payment — show "processing", not "paid".

---

## Two channels, not one flow

`redirectUrl` and `callbackUrl` are both handed to ZenPay in the launch URL, and they are
independent. Do not think of them as a sequence or a race.

- **`redirectUrl` → `GET /return`** — the browser comes back here. This channel exists for
  UI/UX: it tells your app the customer is finished looking at the checkout page. It carries
  **no payment status**, and treating it as though it does is the defining mistake of a bad
  integration. The reference marks the attempt browser-returned (provisional) and forwards to
  the app: mobile to `<PUBLIC_BASE_URL>/zenpay/app-return` (intercepted by the OS as an App
  Link before it becomes a real request), web to `APP_RETURN_URI_WEB`.
- **`callbackUrl` → `POST /api/v1/callbacks`** — ZenPay's server-to-server webhook, and the
  **only** source of truth for payment status. Carries no token, because ZenPay calls it
  directly; authenticated by its `ValidationCode` alone.

### The `/return` route

Validate the signed `t` token first — that is what authorises the lookup. Then:

- **Unknown attempt** → `400 RETURN_TOKEN_UNKNOWN_ATTEMPT`, same as the reference. The
  customer sees a browser error rather than landing back in the app, which is loud and
  obvious — the right tradeoff for a demo, where a silent failure teaches nothing. Worth a
  comment at the call site noting a production merchant would likely redirect with an error
  code instead.
- **Never downgrade a terminal status.** The reference sets `browserReturned` only when the
  attempt is not already `successful`, `failed`, `cancelled`, or `error`. The two channels
  are independent, so a verified callback can already have landed — letting the browser
  return overwrite it would throw away the authoritative answer.
- **Forward the `t` through** to the app return URI unchanged. It is what the app needs for
  its status lookup, and minting a second token would be pointless work.

---

## Handling the callback

Verifying the signature is one line (see `backend-wiring.md`). The lifecycle around it is
where a from-scratch backend goes wrong. The reference's handling is in
`example/backend/lib/src/server_app.dart`'s `_handleCallback`.

**Delivery is fire-and-forget — ZenPay does not retry** (per the ZenPay product owner, not
something the code in this repo states). This single fact drives everything below: a callback
your backend refuses is not redelivered, and that payment's status is never learned by anyone.
Reject only what you genuinely cannot accept.

**Find the attempt by MUPID.** It arrives at `payload['response']['merchantUniquePaymentId']`
— that is the join key between a webhook and a stored attempt. There is no other correlator.

**Statuses the reference returns**, and what each costs given no retries:

| Situation | Reference returns | Consequence |
|---|---|---|
| MUPID missing from body | `400 CALLBACK_MERCHANT_PAYMENT_ID_REQUIRED` | unattributable; nothing to do |
| MUPID names no stored attempt | `404 CALLBACK_ATTEMPT_NOT_FOUND` | **status lost permanently** — the usual cause is a TTL purge, so consider how long a demo keeps attempts |
| Body fails the schema for its mode | `400 CALLBACK_BODY_INVALID` | lost |
| `ValidationCode` fails | `401 CALLBACK_VALIDATION_FAILED` | correct to reject — this is not from ZenPay |
| Verified, first time | stores and `200`s | |
| Verified, repeat with the *same* reference and status | re-applies idempotently | safe |
| Verified, repeat with a *different* reference or status | `409 CALLBACK_CONFLICT` | deliberate: two different truths for one payment is a problem to surface, not to silently overwrite |

The duplicate comparison uses `constantTimeEqual`, like every other reference comparison in
this backend.

**Store the reference under the right field for the mode** — `0`/`2` → `paymentReference`,
`3` → `preauthReference`, `1` → `tokenReference`. `mode.callbackReferenceField` gives you the
name to read out of the payload; the storage mapping is yours.

**Mode `1` carries no status field at all.** For tokenise, reaching a verified callback *is*
the success signal — the reference reports it as successful rather than looking for a
`paymentStatus` that will never be there.

---

## Transaction modes

`ZpPluginMode`, from `zenpay_dart/lib/src/models/enums.dart`:

| Wire | Mode | Charges? | Amount | Reference field on callback |
|---|---|---|---|---|
| `0` | `makePayment` | yes | required, positive | `paymentReference` |
| `1` | `tokenise` | no | optional — shown for pricing, never charged | `token` |
| `2` | `customPayment` | yes | required, positive; hashed as `"0"` in the fingerprint | `paymentReference` |
| `3` | `preauthorization` | yes | required, positive | `preauthReference` |

Pick from the product: selling something at a set price → `0`. Storing a card for later →
`1`. Customer types their own amount (donation, invoice top-up) → `2`. Holding funds
(booking, deposit) → `3`.

**Build one mode, not a picker.** `example/app` ships all four because it is the reference
for the whole SDK. A generated demo is a merchant's product, and a coffee shop does not
offer its customers a pre-authorization option. Implement the one the product implies; if it
is worth showing what the others would change, leave a short comment at the call site rather
than a second code path.

**Amount rules** (`_resolveAmount` in `session_service.dart`): mode `1` may omit the amount
entirely — absent means plain card storage, present means the amount is displayed for
pricing or fees but never charged. Every other mode requires a positive amount, or the
backend returns `400 INVALID_CHECKOUT_AMOUNT`.

Apple Pay / Google Pay one-off flags are only set for mode `0` in the reference
(`session_service.dart`) — wallets are a payment, not a tokenisation.

## Payment status codes

`ZpPaymentStatus`: `0` pending · `1` error · `3` successful · `4` failed · `5` cancelled ·
`6` suppressed · `7` in progress. **Only `3` is success** — `isZpPaymentSuccessful(status)`
and `ZpPaymentStatus.isSuccessful` both mean exactly `== 3`. Do not treat "not failed" as
paid.

---

## Errors

Non-2xx bodies are `{"error": "MACHINE_CODE"}`. Codes worth handling in a demo:

| Code | Means |
|---|---|
| `SESSION_CONFIG_REQUIRED` (503) | `.env` is missing ZenPay credentials or `TOKEN_SECRET` — the most common first-run failure. Say which file to edit |
| `INVALID_CHECKOUT_AMOUNT` (400) | amount missing or ≤ 0 for a mode that requires one |
| `IDEMPOTENCY_KEY_REUSED` (409) | same key, different order fields |
| `CHECKOUT_TOKEN_INVALID` (401) | expired or tampered checkout token |
| `CHECKOUT_ATTEMPT_NOT_FOUND` (404) | token names an attempt the store purged (TTL) |

A demo that surfaces `SESSION_CONFIG_REQUIRED` as "add your ZenPay credentials to
`.env`" saves more time than any other error handling you can write.
