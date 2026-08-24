# ZenPay Dart Backend Agent Guidelines

Guidelines and standards for working within `zenpay_dart` (pure Dart SDK). This package is responsible for all server-side logic, API models, and cryptography.

---

# ZenPay Dart Core Library — Source Architecture & File Guide

Overview of all source files in `lib/`, detailing each file's purpose along with a concise single-line breakdown of every class, function, enum, and extension type explaining what it does, why it exists, and where it is used.

### `lib/src/callback_token.dart`

**Overview:** Implements stateless, HMAC-SHA3-512 signed callback URL token creation and constant-time verification for backend webhooks.

- **`class ZpCallbackUrlTokenPayload`**: Container holding decoded token claims (`mode`, `merchantUniquePaymentId`, `timestamp`, `paymentAmount`, `extra`); passed to `createZpCallbackUrlToken` and returned in `ZpCallbackUrlTokenVerified`.
- **`class ZpCallbackUrlTokenOptions`**: Configuration options for token generation such as `expiresInSeconds`; passed as an optional argument to `createZpCallbackUrlToken`.
- **`sealed class ZpCallbackUrlTokenResult`**: Base result class for token verification, exhaustively pattern-matched with a `switch` over `ZpCallbackUrlTokenVerified`/`ZpCallbackUrlTokenFailure` — matching the other three result types in this package (`ZpCallbackResult`, `ZpFingerprintResult`, `ZpUrlResult`); returned by `verifyZpCallbackUrlToken`.
- **`final class ZpCallbackUrlTokenVerified`**: Represents a successfully verified callback token containing the recovered `ZpCallbackUrlTokenPayload`; pattern-matched in token verification handlers.
- **`enum ZpCallbackUrlTokenFailureReason`**: Enumerates why token verification failed (`malformed`, `badSignature`, `expired`); stored on `ZpCallbackUrlTokenFailure.reason`.
- **`final class ZpCallbackUrlTokenFailure`**: Represents a failed callback token verification containing the specific `ZpCallbackUrlTokenFailureReason`; pattern-matched to handle invalid tokens.
- **`createZpCallbackUrlToken(ZpCallbackUrlTokenPayload payload, Object secret, [ZpCallbackUrlTokenOptions options])`**: Mints a base64url-encoded HMAC-SHA3-512 signed callback token embedding payload claims; used by backend servers when constructing launch `callbackUrl` query parameters (`?t=`).
- **`verifyZpCallbackUrlToken(String token, Object secret)`**: Verifies the HMAC-SHA3-512 signature, checks expiry, and decodes payload claims in constant time; called by backends receiving webhook callbacks to authenticate URL-bound metadata.

### `lib/src/callback.dart`

**Overview:** Implements incoming ZenPay server-to-server callback authentication over a single constant-time SHA3-512 hash verification.

- **`class ZpVerifyCallbackContext`**: Encapsulates merchant credentials (`apiKey`, `username`, `password`), payment amount, and `merchantUniquePaymentId` used for hash verification; passed to `verifyZpCallback`.
- **`sealed class ZpCallbackResult`**: Base sealed class for callback verification outcomes (`ZpCallbackVerified`, `ZpCallbackMalformed`, `ZpCallbackRejected`); exhaustively pattern-matched by server callback handlers.
- **`final class ZpCallbackVerified`**: Carries no data — mirrors `@ianmenethil/zp-hcp`'s TypeScript `verifyZpCallback` (`{ isValid: boolean }`, no returned body). The caller already holds the full callback body it passed in and reads whatever fields it needs (business, reconciliation, or card/account-shaped) directly off that, using `ZpPluginMode.callbackReferenceField` to find the right reference field per mode. Returned when `verifyZpCallback` confirms a valid signature.
- **`final class ZpCallbackMalformed`**: Represents a structural schema error (missing response object or empty reference); returned by `verifyZpCallback` and `validateZpCallbackBody` to signal 400 Bad Request responses.
- **`final class ZpCallbackRejected`**: Represents a cryptographic authenticity failure (invalid validationCode hash); returned by `verifyZpCallback` to signal 401 Unauthorized responses.
- **`validateZpCallbackBody(ZpPluginMode mode, Map<String, Object?> body)`**: Validates that incoming callback JSON matches the required schema for the given mode without recomputing cryptographic hashes; used for pre-flight validation.
- **`verifyZpCallback(ZpPluginMode mode, Map<String, Object?> body, ZpVerifyCallbackContext context)`**: Recomputes the expected SHA3-512 `ValidationCode` and validates the callback in constant time; primary server entrypoint for authenticating ZenPay webhooks.

### `lib/src/checkout_url.dart`

**Overview:** Constructs hosted-checkout Authorise URLs with single-pass percent-encoding and parameter validation.

- **`class ZpCheckoutOptions`**: Complete request specification holding credentials, fingerprints, customer info, callback/redirect URLs, and presentation/payment method flags; passed to `createZpCheckoutUrl`.
- **`sealed class ZpUrlResult`**: Base sealed result class representing URL generation outcomes (`ZpUrlSuccess` or `ZpUrlFailure`); returned by `createZpCheckoutUrl`.
- **`final class ZpUrlSuccess`**: Holds the fully assembled, percent-encoded HTTPS checkout launch URL string; pattern-matched upon successful URL generation.
- **`final class ZpUrlFailure`**: Carries human-readable validation error messages explaining why URL assembly failed; pattern-matched when requests violate parameter constraints.
- **`validateZpCheckoutUrlRequest(ZpCheckoutOptions request)`**: Validates request parameters (credentials, endpoints, email formats, required customer fields) without building a URL; called internally by `createZpCheckoutUrl` and usable for pre-validation.
- **`createZpCheckoutUrl(ZpCheckoutOptions request)`**: Validates inputs, formats query parameters with strict percent-encoding, and constructs the complete ZenPay Authorise launch URL; called by backend servers when creating sessions.

### `lib/src/crypto.dart`

**Overview:** Provides shared cryptographic primitives, constant-time comparisons, dollar-to-cents hash conversions, and ID generation utilities. Also holds hash-pipe constants shared across `fingerprint.dart`, `callback.dart`, and `callback_token.dart` — public (no leading `_`) so sibling files in `lib/src/` can import them, but omitted from `zenpay_dart.dart`'s `show` list so they are not part of the package's public API.

- **`extension type const ZpCents(String value)`**: Type-safe wrapper around whole-number cents strings to prevent accidental dollar-to-cents unit confusion in hash pipes; used across fingerprinting and callback hashing.
- **`extension type const ZpMupid(String value)`**: Type-safe wrapper representing the unique Merchant Unique Payment Identifier; used throughout launch URLs, fingerprints, and callback contexts.
- **`extension type const ZpTimestamp(String value)`**: Type-safe wrapper representing an ISO 8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SS`); used in fingerprint calculations and launch parameters.
- **`createSha3_512(String input)`**: Generates a 128-character lowercase hexadecimal SHA3-512 hash from an input string; core hashing function used for fingerprints and callback validation codes.
- **`constantTimeHexEqual(String a, String b)`**: Compares two hexadecimal hash digest strings in constant time to eliminate timing attack side-channels; used during validation code verification.
- **`zpAmountToCents(Object amount)`**: Converts numeric or string dollar amounts (up to 2 decimal places) into exact integer cents strings; used by hash pipe builders.
- **`resolveZpHashAmountField(ZpPluginMode mode, Object amount)`**: Determines the exact cents value to include in the hash pipe according to mode rules (e.g. forced `"0"` for custom payment and empty tokenise); used in fingerprint and callback hashing.
- **`createZpMupid()`**: Generates a 22-character unpadded base64url random identifier from 16 secure random bytes; used by merchant backends to mint unique payment IDs.
- **`createZpTimestamp()`**: Generates a slice-19 UTC ISO 8601 timestamp string (`YYYY-MM-DDTHH:MM:SS`); used to timestamp checkout launches and fingerprint requests.
- **`isValidZpTimestamp(String timestamp)`**: Checks whether a string strictly matches the required `yyyy-MM-ddTHH:mm:ss` timestamp format; used during request validation.

### `lib/src/constants.dart`

**Overview:** Internal constants and error messages for ZenPay HCP — hash-pipe constraints, regex patterns, error message text, and callback URL token payload keys, shared across `crypto.dart`, `fingerprint.dart`, `callback.dart`, and `callback_token.dart`.

- **`abstract final class ZpCore`**: Namespace for fundamental constraints and primitives — `base64Padding`, `pipeDelimiter`, `minCredentialLength`, `minSecretBytes`, `signatureBytes`, `authoriseActionPath`.
- **`abstract final class ZpPatterns`**: Namespace for validation regular expressions — `amount`, `timestamp`, `validationCode`, `email`, `hcpEndpoint`.
- **`abstract final class ZpErrors`**: Namespace for every error message used internally by ZenPay HCP, covering crypto/primitives, fingerprint, checkout URL, and callback verification failures.
- **`abstract final class ZpCbTokenKeys`**: Namespace for the short keys (`m`, `u`, `t`, `iat`, `a`, `exp`) used in JWT-style callback URL tokens to compress payload size.

### `lib/src/defaults.dart`

**Overview:** Defines default configuration values for hosted checkout options, closely mirroring the TypeScript SDK's defaults.

- **`abstract final class ZpCheckoutDefaults`**: Namespace holding static constants for default option values (e.g., `mode`, `displayMode`, `hideHeader`); used internally to populate omitted parameters.

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

### `lib/src/fingerprint.dart`

**Overview:** Implements outgoing Authorise fingerprint calculation using SHA3-512 over pipe-delimited merchant credential and order fields.

- **`class ZpFingerprintInput`**: Input data structure containing the seven parameters (`apiKey`, `username`, `password`, `mode`, `paymentAmount`, `merchantUniquePaymentId`, `timestamp`) needed to build an outgoing launch fingerprint; passed to `createZpFingerprint`.
- **`sealed class ZpFingerprintResult`**: Base sealed result class representing fingerprint creation outcomes (`ZpFingerprintSuccess` or `ZpFingerprintFailure`); returned by `createZpFingerprint`.
- **`final class ZpFingerprintSuccess`**: Holds the computed 128-character hexadecimal SHA3-512 fingerprint string; pattern-matched upon successful creation.
- **`final class ZpFingerprintFailure`**: Holds human-readable error messages explaining why fingerprint generation failed; pattern-matched on validation failure.
- **`validateZpFingerprintRequest(ZpFingerprintInput request)`**: Validates credential lengths, timestamp formats, and amount values without computing a hash; used for pre-flight validation.
- **`createZpFingerprint(ZpFingerprintInput request)`**: Validates inputs, formats the pipe-delimited string, and computes the SHA3-512 launch fingerprint; called by backends prior to building checkout URLs.

### `lib/zenpay_dart.dart`

**Overview:** The root library barrel file exporting the public API for pure-Dart server environments while encapsulating internal implementation files in `src/`.

- **`zenpay_dart.dart` (Barrel Export)**: Exports all public callback verifiers, token utilities, launch URL builders, cryptographic types, and wire enums for merchant backend consumers.

---

## 🔗 Related Guides

- **[Monorepo Root](file:///G:/_zp-repos/zp-flutter-sdk/CLAUDE.md)** — General Melos and workspace guidelines.
- **[Flutter Client SDK](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/CLAUDE.md)** — UI and client-side orchestration.
- **[Integration Examples](file:///G:/_zp-repos/zp-flutter-sdk/example/CLAUDE.md)** — Reference merchant backend and app that consume this package.
- **[README.md](README.md)** — Package overview, quick start, API reference.

`AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

---

## 1. Non-Negotiable Security & Cryptographic Rules

1. **Timing-Safe Equality**:
   - All cryptographic hash (SHA3-512 `ValidationCode`), HMAC-SHA3-512 callback tokens, and bearer token comparisons **must** use timing-safe comparison methods (`constantTimeHexEqual`, `constantTimeEqual`, or constant-time digest comparison) to prevent timing attacks.
2. **Credential & Secret Protection**:
   - Never hardcode ZenPay API keys, merchant passwords, shared secrets, or live credentials. Read them from the environment or a secret store — see [example/main.dart](example/main.dart).
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

Adhere strictly to [analysis_options.yaml](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/analysis_options.yaml):

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
   - Follow `dart format` with the repo's 160-character `page_width` (set in the root [analysis_options.yaml](file:///G:/_zp-repos/zp-flutter-sdk/analysis_options.yaml), inherited via this package's own `analysis_options.yaml`).

---

## 3. Verification Commands

This package is part of a Melos monorepo. Before completing any change, ensure all checks pass by running the following from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run lint
melos run test
```
