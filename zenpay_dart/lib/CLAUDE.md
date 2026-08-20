# ZenPay Dart Core Library — Source Architecture & File Guide

Parent guide: [zenpay_dart/CLAUDE.md](../CLAUDE.md). `AGENTS.md` in this folder is a symlink to this file.

This document outlines all source files in the core `zenpay_dart` package (`lib/`), detailing each file's purpose along with a concise single-line breakdown of every class, function, enum, and extension type explaining what it does, why it exists, and where it is used.

---

## 1. `lib/src/callback_token.dart`

**File Path:** [lib/src/callback_token.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/callback_token.dart)  
**Overview:** Implements stateless, HMAC-SHA3-512 signed callback URL token creation and constant-time verification for backend webhooks.

- **`class ZpCallbackUrlTokenPayload`**: Container holding decoded token claims (`mode`, `merchantUniquePaymentId`, `timestamp`, `paymentAmount`, `extra`); passed to `createZpCallbackUrlToken` and returned in `ZpCallbackUrlTokenVerified`.
- **`class ZpCallbackUrlTokenOptions`**: Configuration options for token generation such as `expiresInSeconds`; passed as an optional argument to `createZpCallbackUrlToken`.
- **`sealed class ZpCallbackUrlTokenResult`**: Base result class for token verification, exhaustively pattern-matched with a `switch` over `ZpCallbackUrlTokenVerified`/`ZpCallbackUrlTokenFailure` — matching the other three result types in this package (`ZpCallbackResult`, `ZpFingerprintResult`, `ZpUrlResult`); returned by `verifyZpCallbackUrlToken`.
- **`final class ZpCallbackUrlTokenVerified`**: Represents a successfully verified callback token containing the recovered `ZpCallbackUrlTokenPayload`; pattern-matched in token verification handlers.
- **`enum ZpCallbackUrlTokenFailureReason`**: Enumerates why token verification failed (`malformed`, `badSignature`, `expired`); stored on `ZpCallbackUrlTokenFailure.reason`.
- **`final class ZpCallbackUrlTokenFailure`**: Represents a failed callback token verification containing the specific `ZpCallbackUrlTokenFailureReason`; pattern-matched to handle invalid tokens.
- **`createZpCallbackUrlToken(ZpCallbackUrlTokenPayload payload, Object secret, [ZpCallbackUrlTokenOptions options])`**: Mints a base64url-encoded HMAC-SHA3-512 signed callback token embedding payload claims; used by backend servers when constructing launch `callbackUrl` query parameters (`?t=`).
- **`verifyZpCallbackUrlToken(String token, Object secret)`**: Verifies the HMAC-SHA3-512 signature, checks expiry, and decodes payload claims in constant time; called by backends receiving webhook callbacks to authenticate URL-bound metadata.

---

## 2. `lib/src/callback.dart`

**File Path:** [lib/src/callback.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/callback.dart)  
**Overview:** Implements incoming ZenPay server-to-server callback authentication over a single constant-time SHA3-512 hash verification.

- **`class ZpVerifyCallbackContext`**: Encapsulates merchant credentials (`apiKey`, `username`, `password`), payment amount, and `merchantUniquePaymentId` used for hash verification; passed to `verifyZpCallback`.
- **`sealed class ZpCallbackResult`**: Base sealed class for callback verification outcomes (`ZpCallbackVerified`, `ZpCallbackMalformed`, `ZpCallbackRejected`); exhaustively pattern-matched by server callback handlers.
- **`final class ZpCallbackVerified`**: Carries no data — mirrors `@ianmenethil/zp-hcp`'s TypeScript `verifyZpCallback` (`{ isValid: boolean }`, no returned body). `verifyZpCallback` proves authenticity only; the caller already holds the full callback body it passed in and reads whatever fields it needs (business, reconciliation, or card/account-shaped) directly off that, using `ZpPluginMode.callbackReferenceField` to find the right reference field per mode. Returned when `verifyZpCallback` confirms a valid signature.
- **`final class ZpCallbackMalformed`**: Represents a structural schema error (missing response object or empty reference); returned by `verifyZpCallback` and `validateZpCallbackBody` to signal 400 Bad Request responses.
- **`final class ZpCallbackRejected`**: Represents a cryptographic or identity mismatch (invalid validationCode hash or mismatched mupid); returned by `verifyZpCallback` to signal 401 Unauthorized responses.
- **`validateZpCallbackBody(ZpPluginMode mode, Map<String, Object?> body)`**: Validates that incoming callback JSON matches the required schema for the given mode without recomputing cryptographic hashes; used for pre-flight validation.
- **`verifyZpCallback(ZpPluginMode mode, Map<String, Object?> body, ZpVerifyCallbackContext context)`**: Recomputes the expected SHA3-512 `ValidationCode` and validates the callback in constant time; primary server entrypoint for authenticating ZenPay webhooks.

---

## 3. `lib/src/checkout_url.dart`

**File Path:** [lib/src/checkout_url.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/checkout_url.dart)  
**Overview:** Constructs hosted-checkout Authorise URLs with single-pass percent-encoding and parameter validation.

- **`class ZpCheckoutOptions`**: Complete request specification holding credentials, fingerprints, customer info, callback/redirect URLs, and presentation/payment method flags; passed to `createZpCheckoutUrl`.
- **`sealed class ZpUrlResult`**: Base sealed result class representing URL generation outcomes (`ZpUrlSuccess` or `ZpUrlFailure`); returned by `createZpCheckoutUrl`.
- **`final class ZpUrlSuccess`**: Holds the fully assembled, percent-encoded HTTPS checkout launch URL string; pattern-matched upon successful URL generation.
- **`final class ZpUrlFailure`**: Carries human-readable validation error messages explaining why URL assembly failed; pattern-matched when requests violate parameter constraints.
- **`validateZpCheckoutUrlRequest(ZpCheckoutOptions request)`**: Validates request parameters (credentials, endpoints, email formats, required customer fields) without building a URL; called internally by `createZpCheckoutUrl` and usable for pre-validation.
- **`createZpCheckoutUrl(ZpCheckoutOptions request)`**: Validates inputs, formats query parameters with strict percent-encoding, and constructs the complete ZenPay Authorise launch URL; called by backend servers when creating sessions.

---

## 4. `lib/src/crypto.dart`

**File Path:** [lib/src/crypto.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/crypto.dart)  
**Overview:** Provides shared cryptographic primitives, constant-time comparisons, dollar-to-cents hash conversions, and ID generation utilities. Also holds hash-pipe constants shared across `fingerprint.dart`, `callback.dart`, and `callback_token.dart` — public (no leading `_`) so sibling files in `lib/src/` can import them, but omitted from `zenpay_dart.dart`'s `show` list so they are not part of the package's public API.

- **`zpBase64Padding`**: The `'='` base64url padding character stripped after encoding; shared by `createZpMupid` here and the callback URL token codec in `callback_token.dart`.
- **`zpPipeDelimiter`**: The `'|'` delimiter joining hash-pipe fields; shared by `fingerprint.dart` and `callback.dart`.
- **`zpMinCredentialLength`**: Minimum length (`5`) required for each hash-pipe credential field; shared by `fingerprint.dart` and `callback.dart`.
- **`zpErrPaymentAmountNumber`**: Error message for an unparsable `paymentAmount`; shared by `fingerprint.dart` and `callback.dart`.
- **`zpErrPaymentAmountPositive`**: Error message for a `paymentAmount` that must be positive but isn't; shared by `fingerprint.dart` and `callback.dart`.
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

---

## 5. `lib/src/defaults.dart`

**File Path:** [lib/src/defaults.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/defaults.dart)  
**Overview:** Defines default configuration values for hosted checkout options, closely mirroring the TypeScript SDK's defaults.

- **`abstract final class ZpCheckoutDefaults`**: Namespace holding static constants for default option values (e.g., `mode`, `displayMode`, `hideHeader`); used internally to populate omitted parameters.

---

## 6. `lib/src/enums.dart`

**File Path:** [lib/src/enums.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/enums.dart)  
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

---

## 7. `lib/src/fingerprint.dart`

**File Path:** [lib/src/fingerprint.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/src/fingerprint.dart)  
**Overview:** Implements outgoing Authorise fingerprint calculation using SHA3-512 over pipe-delimited merchant credential and order fields.

- **`class ZpFingerprintInput`**: Input data structure containing the seven parameters (`apiKey`, `username`, `password`, `mode`, `paymentAmount`, `merchantUniquePaymentId`, `timestamp`) needed to build an outgoing launch fingerprint; passed to `createZpFingerprint`.
- **`sealed class ZpFingerprintResult`**: Base sealed result class representing fingerprint creation outcomes (`ZpFingerprintSuccess` or `ZpFingerprintFailure`); returned by `createZpFingerprint`.
- **`final class ZpFingerprintSuccess`**: Holds the computed 128-character hexadecimal SHA3-512 fingerprint string; pattern-matched upon successful creation.
- **`final class ZpFingerprintFailure`**: Holds human-readable error messages explaining why fingerprint generation failed; pattern-matched on validation failure.
- **`validateZpFingerprintRequest(ZpFingerprintInput request)`**: Validates credential lengths, timestamp formats, and amount values without computing a hash; used for pre-flight validation.
- **`createZpFingerprint(ZpFingerprintInput request)`**: Validates inputs, formats the pipe-delimited string, and computes the SHA3-512 launch fingerprint; called by backends prior to building checkout URLs.

---

## 8. `lib/zenpay_dart.dart`

**File Path:** [lib/zenpay_dart.dart](file:///g:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/zenpay_dart.dart)  
**Overview:** The root library barrel file exporting the public API for pure-Dart server environments while encapsulating internal implementation files in `src/`.

- **`zenpay_dart.dart` (Barrel Export)**: Exports all public callback verifiers, token utilities, launch URL builders, cryptographic types, and wire enums for merchant backend consumers.