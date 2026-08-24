/// Internal constants and error messages for ZenPay HCP.
library;

// -----------------------------------------------------------------------------
// Core Crypto & Hash Constraints
// -----------------------------------------------------------------------------

/// Fundamental constraints, tokens, and primitives.
abstract final class ZpCore {
  /// Padding character stripped from base64url output.
  static const base64Padding = '=';

  /// Pipe delimiter joining fields in ZenPay hash strings.
  static const pipeDelimiter = '|';

  /// Minimum length required for ZenPay hash-pipe credential fields.
  static const minCredentialLength = 5;

  /// Minimum length for HMAC-SHA3-512 callback token secrets.
  static const minSecretBytes = 32;

  /// Expected length of HMAC-SHA3-512 signatures in bytes.
  static const signatureBytes = 16;

  /// The URL path fragment used to authorize a checkout session.
  static const authoriseActionPath = 'Authorise';
}

// -----------------------------------------------------------------------------
// Regex Patterns
// -----------------------------------------------------------------------------

/// Regular expressions used for validation.
abstract final class ZpPatterns {
  /// Regex pattern for validating payment amounts.
  static final amount = RegExp(r'^\d+(?:\.\d{1,2})?$');

  /// Regex pattern for validating timestamps.
  static final timestamp = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$');

  /// Regex pattern for validating callback verification codes.
  static final validationCode = RegExp(r'^[0-9a-f]{128}$');

  /// Regex pattern for validating emails.
  static final email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Regex pattern for validating HCP endpoints.
  static final hcpEndpoint = RegExp(
    r'^https://(pay|payuat|pay\.sandbox)\.'
    '(travelpay|childcareeasypay|zenpay|b2bpay|schooleasypay'
    '|thoroughbredpayments|rentalrewards)'
    r'\.com\.au/[Oo]nline/v[45]/?$',
  );
}

// -----------------------------------------------------------------------------
// Error Messages
// -----------------------------------------------------------------------------

/// All error messages used internally by ZenPay HCP.
abstract final class ZpErrors {
  // Crypto & Primitives
  /// Error: Payment amount must be a number.
  static const paymentAmountNumber = 'paymentAmount must be a valid number';

  /// Error: Payment amount must be positive.
  static const paymentAmountPositive = 'paymentAmount must be greater than 0';

  /// Error: Payment amount unresolvable.
  static String paymentAmountUnresolvable(Object? amount) => 'invalid amount "$amount" — expected a non-negative number with at most 2 decimal places';

  // Fingerprint
  /// Error: apiKey length.
  static const apiKeyLength = 'apiKey must be at least ${ZpCore.minCredentialLength} characters';

  /// Error: username length.
  static const usernameLength = 'username must be at least ${ZpCore.minCredentialLength} characters';

  /// Error: password length.
  static const passwordLength = 'password must be at least ${ZpCore.minCredentialLength} characters';

  /// Error: MUPID length.
  static const mupidLength = 'merchantUniquePaymentId must be at least ${ZpCore.minCredentialLength} characters';

  /// Error: Timestamp format.
  static const timestampFormat = 'timestamp must be in YYYY-MM-DDTHH:MM:SS format';

  // Checkout URL
  /// Error: apiKey or fingerprint empty.
  static const apiKeyOrFingerprintEmpty = 'apiKey and fingerprint must not be empty';

  /// Error: merchantCode empty.
  static const merchantCodeEmpty = 'merchantCode must not be empty';

  /// Error: merchantCode would not occupy exactly one URL path segment.
  static const merchantCodeInvalidPathSegment = 'merchantCode must not contain "/" and must not be "." or ".."';

  /// Error: callback or redirect empty.
  static const callbackOrRedirectEmpty = 'at least one of callbackUrl or redirectUrl must be provided';

  /// Error: departureDate required for SlicePay.
  static const slicePayDateRequired = 'departureDate must be provided when slicePay is allowed';

  /// Error: customerName and reference required.
  static const customerNameAndRefRequired = 'customerName and customerReference must be provided for this mode';

  // Callback Verification
  /// Error: validationCode must be hex.
  static const validationCodeHex = 'validationCode must be a 128-character hex string';

  /// Error: validationCode mismatch.
  static const validationCodeMismatch = 'validationCode does not match the computed hash';

  /// Error: credential length.
  static const credentialLength =
      'apiKey, username, password, and merchantUniquePaymentId must be at '
      'least ${ZpCore.minCredentialLength} characters';

  /// Error: body malformed.
  static const malformedBody = 'body must contain a response object and a validationCode string';
}

// -----------------------------------------------------------------------------
// Token Payload Keys
// -----------------------------------------------------------------------------

/// Short keys used in JWT-style callback URL tokens to compress payload size.
abstract final class ZpCbTokenKeys {
  /// Token Key: mode.
  static const mode = 'm';

  /// Token Key: MUPID.
  static const mupid = 'u';

  /// Token Key: timestamp.
  static const timestamp = 't';

  /// Token Key: issued at.
  static const issuedAt = 'iat';

  /// Token Key: amount.
  static const amount = 'a';

  /// Token Key: expires at.
  static const expiresAt = 'exp';
}
