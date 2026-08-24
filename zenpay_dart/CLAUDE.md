# zenpay_dart — Pure Dart Backend SDK

Server-side logic, API models, and cryptography for ZenPay Hosted Checkout: fingerprints, launch URLs, callback verification, callback URL tokens. Server-side only — never import this from a Flutter mobile app or frontend package (it handles credentials and signing).

---

# ZenPay Dart Core Library — Source Architecture & File Guide

Overview of all source files in `lib/`, detailing each file's purpose along with a concise single-line breakdown of every class, function, enum, and extension type explaining what it does, why it exists, and where it is used.

### `lib/src/build_checkout_url.dart`

**Overview:** Constructs hosted-checkout Authorise URLs with single-pass percent-encoding and parameter validation. Every query value is percent-encoded exactly once via `Uri`; ZenPay's own browser plugin double-decodes the reassembled query string, which this builder deliberately does not replicate. `ZpCheckoutOptions` itself now lives in `models/checkout_options.dart`.

- **`sealed class ZpUrlResult`**: Base sealed result class representing URL generation outcomes (`ZpUrlSuccess` or `ZpUrlFailure`); returned by `createZpCheckoutUrl`.
- **`final class ZpUrlSuccess`**: Holds the fully assembled, percent-encoded checkout launch `url`, plus `height`/`maxWidth` presentation hints; pattern-matched upon successful URL generation.
- **`final class ZpUrlFailure`**: Carries a human-readable validation error `message` explaining why URL assembly failed; pattern-matched when requests violate parameter constraints.
- **`validateZpCheckoutUrlRequest(ZpCheckoutOptions request)`**: Validates request parameters (credentials, endpoints, email formats, required customer fields, and that `merchantCode` occupies exactly one URL path segment) without building a URL; called internally by `createZpCheckoutUrl` and usable for pre-validation.
- **`createZpCheckoutUrl(ZpCheckoutOptions request)`**: Validates inputs, formats query parameters with strict percent-encoding, and constructs the complete ZenPay Authorise launch URL; called by backend servers when creating sessions.

### `lib/src/build_fingerprint.dart`

**Overview:** Implements outgoing Authorise fingerprint calculation using SHA3-512 over pipe-delimited merchant credential and order fields. `ZpFingerprintInput` and the `ZpFingerprintResult` hierarchy now live in `models/fingerprint_result.dart`.

- **`validateZpFingerprintRequest(ZpFingerprintInput request)`**: Validates credential lengths, timestamp format, and amount value without computing a hash; used for pre-flight validation.
- **`createZpFingerprint(ZpFingerprintInput request)`**: Validates inputs, formats the pipe-delimited string, and computes the SHA3-512 launch fingerprint; called by backends prior to building checkout URLs.

### `lib/src/checkout_defaults.dart`

**Overview:** Defines default option and UI-hint values applied when the caller omits them, closely mirroring the TypeScript SDK's defaults.

- **`abstract final class ZpCheckoutDefaults`**: Namespace holding static constants for default option values (e.g., `mode`, `overrideFeePayer`, `userMode`, `displayMode`, `hideHeader`); used internally to populate omitted `ZpCheckoutOptions` fields. `displayMode` deliberately diverges from the TypeScript default (Redirect instead of Modal) since this SDK only ever launches a Custom Tab / `SFSafariViewController`, which cannot render a Modal iframe.
- **`abstract final class ZpUiDefaults`**: Namespace holding static constants for output/rendering hints applied at URL-build time (`titleFallback`, `titleFallbackTokenise`, `maxWidth`, `heightTokenise`, `heightDefault`) rather than merged into the request; the per-mode title fallbacks are a zenpay_dart-specific addition beyond the ported TypeScript source.

### `lib/src/constants.dart`

**Overview:** Internal constants and error messages for ZenPay HCP — hash-pipe constraints, regex patterns, error message text, and callback URL token payload keys, shared across `crypto_utils.dart`, `build_fingerprint.dart`, `verify_callback.dart`, and `sign_callback_token.dart`.

- **`abstract final class ZpCore`**: Namespace for fundamental constraints and primitives — `base64Padding`, `pipeDelimiter`, `minCredentialLength`, `minSecretBytes`, `signatureBytes`, `authoriseActionPath`.
- **`abstract final class ZpPatterns`**: Namespace for validation regular expressions — `amount`, `timestamp`, `validationCode`, `email`, `hcpEndpoint`.
- **`abstract final class ZpErrors`**: Namespace for every error message used internally by ZenPay HCP, covering crypto/primitives, fingerprint, checkout URL (including `merchantCodeInvalidPathSegment`), and callback verification failures.
- **`abstract final class ZpCbTokenKeys`**: Namespace for the short keys (`m`, `u`, `t`, `iat`, `a`, `exp`) used in JWT-style callback URL tokens to compress payload size.

### `lib/src/crypto_utils.dart`

**Overview:** Provides shared cryptographic primitives, constant-time comparisons, dollar-to-cents hash conversions, and ID generation utilities. Also holds hash-pipe constants shared across `build_fingerprint.dart`, `verify_callback.dart`, and `sign_callback_token.dart` — public (no leading `_`) so sibling files in `lib/src/` can import them, but omitted from `zenpay_dart.dart`'s `show` list so `ZpAmountFailureReason`/`resolveZpHashAmountChecked` are not part of the package's public API.

- **`extension type const ZpCents(String value)`**: Type-safe wrapper around whole-number cents strings to prevent accidental dollar-to-cents unit confusion in hash pipes; used across fingerprinting and callback hashing.
- **`extension type const ZpMupid(String value)`**: Type-safe wrapper representing the unique Merchant Unique Payment Identifier; used throughout launch URLs, fingerprints, and callback contexts.
- **`extension type const ZpTimestamp(String value)`**: Type-safe wrapper representing an ISO 8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SS`); used in fingerprint calculations and launch parameters.
- **`createSha3_512(String input)`**: Generates a 128-character lowercase hexadecimal SHA3-512 hash from an input string; core hashing function used for fingerprints and callback validation codes.
- **`constantTimeHexEqual(String a, String b)`**: Compares two hexadecimal hash digest strings in constant time to eliminate timing attack side-channels; used during validation code verification.
- **`zpAmountToCents(Object? amount)`**: Converts numeric or string dollar amounts (up to 2 decimal places) into exact integer cents strings, returning `null` when invalid; used by hash pipe builders.
- **`resolveZpHashAmountField(ZpPluginMode mode, Object? amount)`**: Determines the exact cents value to include in the hash pipe according to mode rules (e.g. forced `"0"` for custom payment and empty tokenise); used in fingerprint and callback hashing.
- **`enum ZpAmountFailureReason`**: Enumerates why `resolveZpHashAmountChecked` failed (`notANumber`, `notPositive`, `unresolvable`); used to select the matching `ZpErrors` message in `build_fingerprint.dart` and `verify_callback.dart`.
- **`resolveZpHashAmountChecked(ZpPluginMode mode, Object? amount)`**: Validates `amount` for `mode` (numeric parse, positivity per `requiresPositiveAmount`) and resolves the hash-pipe cents value in one pass, returning a `(ZpCents?, ZpAmountFailureReason?)` record; shared validation core for both fingerprint creation and callback verification.
- **`createZpMupid()`**: Generates a 22-character unpadded base64url random identifier from 16 secure random bytes; used by merchant backends to mint unique payment IDs.
- **`createZpTimestamp()`**: Generates a slice-19 UTC ISO 8601 timestamp string (`YYYY-MM-DDTHH:MM:SS`); used to timestamp checkout launches and fingerprint requests.
- **`isValidZpTimestamp(String timestamp)`**: Checks whether a string strictly matches the required `yyyy-MM-ddTHH:mm:ss` timestamp format; used during request validation.

### `lib/src/models/callback_input.dart`

**Overview:** Models for incoming ZenPay server-to-server callback verification — the merchant-known context passed into `verifyZpCallback` and its result hierarchy. Split out of what was `callback.dart`.

- **`class ZpVerifyCallbackContext`**: Encapsulates merchant credentials (`apiKey`, `username`, `password`), `paymentAmount`, and `merchantUniquePaymentId` used for hash verification; passed to `verifyZpCallback`.
- **`sealed class ZpCallbackResult`**: Base sealed class for callback verification outcomes (`ZpCallbackVerified`, `ZpCallbackMalformed`, `ZpCallbackRejected`); exhaustively pattern-matched by server callback handlers.
- **`final class ZpCallbackVerified`**: Carries no data — mirrors `@ianmenethil/zp-hcp`'s TypeScript `verifyZpCallback` (`{ isValid: boolean }`, no returned body). The caller already holds the full callback body it passed in and reads whatever fields it needs (business, reconciliation, or card/account-shaped) directly off that, using `ZpPluginMode.callbackReferenceField` to find the right reference field per mode. Returned when `verifyZpCallback` confirms a valid signature.
- **`final class ZpCallbackMalformed`**: Represents a structural schema error (missing response object or empty reference); returned by `verifyZpCallback` and `validateZpCallbackBody` to signal 400 Bad Request responses.
- **`final class ZpCallbackRejected`**: Represents a cryptographic authenticity failure (invalid validationCode hash); returned by `verifyZpCallback` to signal 401 Unauthorized responses.

### `lib/src/models/callback_token_data.dart`

**Overview:** Models for the signed callback URL token payload, creation options, and verification results. Split out of what was `callback_token.dart`.

- **`class ZpCallbackUrlTokenPayload`**: Container holding decoded token claims (`mode`, `merchantUniquePaymentId`, `timestamp`, `paymentAmount`, `extra`); passed to `createZpCallbackUrlToken` and returned in `ZpCallbackUrlTokenVerified`.
- **`class ZpCallbackUrlTokenOptions`**: Configuration options for token generation such as `expiresInSeconds`; passed as an optional argument to `createZpCallbackUrlToken`.
- **`sealed class ZpCallbackUrlTokenResult`**: Base result class for token verification, exhaustively pattern-matched with a `switch` over `ZpCallbackUrlTokenVerified`/`ZpCallbackUrlTokenFailure` — matching the other three result types in this package (`ZpCallbackResult`, `ZpFingerprintResult`, `ZpUrlResult`); returned by `verifyZpCallbackUrlToken`.
- **`final class ZpCallbackUrlTokenVerified`**: Represents a successfully verified callback token containing the recovered `ZpCallbackUrlTokenPayload`; pattern-matched in token verification handlers.
- **`enum ZpCallbackUrlTokenFailureReason`**: Enumerates why token verification failed (`malformed`, `badSignature`, `expired`); stored on `ZpCallbackUrlTokenFailure.reason`.
- **`final class ZpCallbackUrlTokenFailure`**: Represents a failed callback token verification containing the specific `ZpCallbackUrlTokenFailureReason`; pattern-matched to handle invalid tokens.

### `lib/src/models/checkout_options.dart`

**Overview:** Defines `ZpCheckoutOptions`, the hosted-checkout Authorise request model. Split out of what was `checkout_url.dart`.

- **`class ZpCheckoutOptions`**: Complete request specification — every field ZenPay's hosted-checkout endpoint accepts minus browser-only concerns (theme, fonts, modal sizing, lifecycle callbacks) — holding credentials, the fingerprint, customer info, callback/redirect URLs, and presentation/payment method flags, with per-field defaults sourced from `ZpCheckoutDefaults`; passed to `createZpCheckoutUrl`.

### `lib/src/models/enums.dart`

**Overview:** Defines strongly typed vocabularies and wire integer mappings for ZenPay HCP modes, display styles, user types, fee payers, and payment status codes.

- **`enum ZpPluginMode`**: Defines ZenPay operating modes (`makePayment: 0`, `tokenise: 1`, `customPayment: 2`, `preauthorization: 3`); controls payment capture behavior and hash pipe construction.
- **`ZpPluginMode.fromWireValue(int value)`**: Resolves a mode enum from its wire integer representation, throwing `ArgumentError` if unrecognized; used when deserializing mode parameters.
- **`ZpPluginMode.requiresPositiveAmount`**: Boolean getter indicating if a mode strictly requires a positive dollar amount (true for modes 0, 2, 3); used in input validation.
- **`ZpPluginMode.callbackReferenceField`**: Returns the response field name carrying the transaction reference for this mode (`paymentReference`, `preauthReference`, `token`); used in callback parsing.
- **`enum ZpDisplayMode`**: Defines hosted checkout display presentation modes (`modal: 0`, `redirectUrl: 1`); sent in launch URLs.
- **`enum ZpUserMode`**: Specifies checkout UI skin targets (`customer: 0`, `merchant: 1`); sent in launch URLs to adjust presentation for customer self-service vs operator MOTO.
- **`enum ZpOverrideFeePayer`**: Configures who absorbs the transaction surcharge (`accountDefault: 0`, `merchant: 1`, `customer: 2`); serialized into launch URL query parameters.
- **`enum ZpPaymentStatus`**: Enumerates ZenPay transaction status wire codes (`pending: 0`, `error: 1`, `successful: 3`, `failed: 4`, `cancelled: 5`, `suppressed: 6`, `inProgress: 7`); used to interpret callback status codes.
- **`ZpPaymentStatus.tryFromWireValue(int value)`**: Safely maps wire integer codes to the `ZpPaymentStatus` enum, returning `null` for unknown codes; used in callback parsing.
- **`ZpPaymentStatus.isSuccessful`**: Boolean getter returning true strictly for `ZpPaymentStatus.successful` (code `3`); used for reliable payment completion checks.
- **`isZpPaymentSuccessful(int status)`**: Utility function checking whether a raw integer status code indicates successful payment (`status == 3`); used by callers holding primitive integers.

### `lib/src/models/fingerprint_result.dart`

**Overview:** Models for outgoing Authorise fingerprint generation — the request input and the `ZpFingerprintResult` hierarchy. Split out of what was `fingerprint.dart`.

- **`class ZpFingerprintInput`**: Input data structure containing the seven parameters (`apiKey`, `username`, `password`, `mode`, `paymentAmount`, `merchantUniquePaymentId`, `timestamp`) needed to build an outgoing launch fingerprint; passed to `createZpFingerprint`.
- **`sealed class ZpFingerprintResult`**: Base sealed result class representing fingerprint creation outcomes (`ZpFingerprintSuccess` or `ZpFingerprintFailure`); returned by `createZpFingerprint`.
- **`final class ZpFingerprintSuccess`**: Holds the computed 128-character hexadecimal SHA3-512 fingerprint string; pattern-matched upon successful creation.
- **`final class ZpFingerprintFailure`**: Holds a human-readable error message explaining why fingerprint generation failed; pattern-matched on validation failure.

### `lib/src/sign_callback_token.dart`

**Overview:** Implements stateless, HMAC-SHA3-512 signed callback URL token creation and constant-time verification for backend webhooks. `ZpCallbackUrlTokenPayload`/`ZpCallbackUrlTokenOptions`/`ZpCallbackUrlTokenResult` now live in `models/callback_token_data.dart`. Split out of and renamed from `callback_token.dart`.

- **`createZpCallbackUrlToken(ZpCallbackUrlTokenPayload payload, Object secret, [ZpCallbackUrlTokenOptions options])`**: Mints a base64url-encoded HMAC-SHA3-512 signed callback token embedding payload claims; used by backend servers when constructing launch `callbackUrl` query parameters (`?t=`). Throws `ArgumentError` for a malformed payload or secret — caller-constructed data, so failing fast is appropriate.
- **`verifyZpCallbackUrlToken(String token, Object secret)`**: Verifies the HMAC-SHA3-512 signature, checks expiry, and decodes payload claims in constant time; called by backends receiving webhook callbacks to authenticate URL-bound metadata. Throws `ArgumentError` only for a malformed `secret`; a malformed or tampered `token` returns `ZpCallbackUrlTokenFailure` instead of throwing, since it is attacker-reachable wire input.

### `lib/src/verify_callback.dart`

**Overview:** Implements incoming ZenPay server-to-server callback authentication over a single constant-time SHA3-512 hash verification. `ZpVerifyCallbackContext` and the `ZpCallbackResult` hierarchy now live in `models/callback_input.dart`. Split out of and renamed from `callback.dart`.

- **`validateZpCallbackBody(ZpPluginMode mode, Map<String, Object?> body)`**: Validates that incoming callback JSON matches the required structural shape for the given mode (a `response` object, a non-empty mode-specific reference, a 128-character hex `validationCode`) without recomputing cryptographic hashes; used for pre-flight validation. Does not verify authenticity.
- **`verifyZpCallback(ZpPluginMode mode, Map<String, Object?> body, ZpVerifyCallbackContext context)`**: Recomputes the expected SHA3-512 `validationCode` and validates the callback in constant time; primary server entrypoint for authenticating ZenPay webhooks. Never throws for malformed callback data — returns `ZpCallbackMalformed`/`ZpCallbackRejected` instead.

### `lib/zenpay_dart.dart`

**Overview:** The root library barrel file exporting the public API for pure-Dart server environments while encapsulating internal implementation files in `src/`.

- **`zenpay_dart.dart` (Barrel Export)**: Exports `build_checkout_url.dart`, `build_fingerprint.dart`, a curated `show` subset of `crypto_utils.dart` (`ZpCents`, `ZpMupid`, `ZpTimestamp`, `createSha3_512`, `createZpMupid`, `createZpTimestamp`, `isValidZpTimestamp`, `resolveZpHashAmountField`, `zpAmountToCents` — `ZpAmountFailureReason`/`resolveZpHashAmountChecked` stay internal), every `models/*.dart` file, `sign_callback_token.dart`, and `verify_callback.dart` for merchant backend consumers. `checkout_defaults.dart` and `constants.dart` are not exported — internal only, matching the TypeScript SDK.

---

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[Flutter Client SDK](../zenpay_flutter/CLAUDE.md)** — UI and client-side orchestration.
- **[Integration Examples](../example/CLAUDE.md)** — Reference merchant backend and app that consume this package.
- **[README.md](README.md)** — Package overview, quick start, API reference.

---

## 1. Security & Cryptographic Rules

1. **Timing-Safe Equality**:
   - All cryptographic hash (SHA3-512 `ValidationCode`), HMAC-SHA3-512 callback tokens, and bearer token comparisons **must** use timing-safe comparison methods (`constantTimeHexEqual`, `constantTimeEqual`, or constant-time digest comparison) to prevent timing attacks.
2. **Credential & Secret Protection**:
   - Never hardcode ZenPay API keys, merchant passwords, shared secrets, or live credentials — read them from the environment or a secret store. `example/` (regenerated by `dart run cli.dart --sync-examples` — see root `CLAUDE.md`) demonstrates the pattern.
   - Do not log sensitive fields (passwords, cardholder numbers, CVV, authentication secrets).
   - Safe to log for debugging: `merchantUniquePaymentId`, merchant codes, checkout launch URLs, customer reference IDs, and callback event types.

   **Public vs secret — do not mask the public values.** These are **public and safe to log in full**, including inside a complete launch URL:

   | Value | Why it is public |
   |---|---|
   | `__ApiKey` | travels in the Authorise URL the customer's own browser loads |
   | `__Fingerprint` | a per-transaction SHA3-512 digest, also in that URL; useless without the password that produced it |
   | `merchantCode` | a merchant identifier in the URL path |
   | `merchantUniquePaymentId` | an ordinary opaque per-payment reference |
   | `timestamp`, `customerReference`, `paymentAmount` | ordinary request fields in the URL |

   So **log the launch URL in full** — do not mask, redact, or partially obscure any of its query values. Masking them adds no security (the browser receives the same URL) and makes logs harder to correlate.

   The genuine secrets, which must never be logged, embedded in a URL, or committed: the **merchant password**, the **HMAC secret** passed to `createZpCallbackUrlToken`, and any **cardholder data** (PAN, CVV, expiry). The merchant password and HMAC secret are hash *inputs* only — they never appear in any URL this package builds. Note the distinct convention in `example/backend`, which masks `authorization` / `x-recaptcha-token` header values: those carry bearer secrets, which is a different class of value from the launch-URL parameters above.
3. **Launch URL Generation**:
   - Launch URLs must be constructed locally using query parameter serialization without making outbound network requests at launch time.
4. **Callback & State Verification**:
   - Only validated callback payloads or authenticated direct ZenPay REST status checks can confirm payment completion. Client redirects or browser dismissals are strictly provisional.

---

## 2. Dart Strictness & Code Quality

Adhere strictly to [analysis_options.yaml](analysis_options.yaml):

1. **Strict Type Safety**:
   - `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`.
   - Never use untyped `dynamic` or `avoid_dynamic_calls`. Use explicit generics and model types.
2. **Public API Documentation**:
   - Every exported class, method, enum, getter, and typedef in `lib/` must have a comprehensive doc comment explaining its parameters, return values, and failure modes — by convention, not lint-enforced. `public_member_api_docs` is disabled package-wide in `analysis_options.yaml`: Dart's primary-constructor syntax (used throughout `lib/src/models/`) gives a class no separate line a constructor doc can attach to, and the rule has no per-construct granularity to exempt just those classes.
3. **Dead Code & Unused Elements**:
   - Unused private members, unused imports, and unused local variables are compiler errors (`error`). Clean them up immediately rather than adding suppression comments.
4. **Style**:
   - Always prefer `final` locals.
   - Sort constructors first.
   - Follow `dart format` with the repo's 160-character `page_width` (set in the root [analysis_options.yaml](../analysis_options.yaml), restated here since this package's own `analysis_options.yaml` must resolve standalone once published — it can't `include: ../` from an extracted package).

---

## 3. Verification Commands

This package is part of a Melos monorepo. Before completing any change, ensure all checks pass by running the following from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run lint
melos run test
```
