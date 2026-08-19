/// In-memory repository for [CheckoutAttempt] records, indexed by
/// `merchantUniquePaymentId` and by idempotency key.
library;

import 'models.dart';

/// Thrown on an internal store invariant violation.
class AttemptStoreError extends Error {
  /// Creates an [AttemptStoreError] with a machine-readable [code].
  AttemptStoreError(this.code);

  /// Machine-readable violation identifier.
  final String code;

  @override
  String toString() => code;
}

/// In-memory checkout-attempt store.
class AttemptStore {
  final _byMerchantPaymentId = <String, CheckoutAttempt>{};
  final _byIdempotencyKey = <String, String>{};

  /// Throws [AttemptStoreError] `'DUPLICATE_CHECKOUT_ATTEMPT'` if [attempt]'s
  /// id already exists.
  void create(CheckoutAttempt attempt) {
    if (_byMerchantPaymentId.containsKey(attempt.merchantUniquePaymentId)) {
      throw AttemptStoreError('DUPLICATE_CHECKOUT_ATTEMPT');
    }
    _byMerchantPaymentId[attempt.merchantUniquePaymentId] = attempt;
    _byIdempotencyKey[attempt.idempotencyKey] = attempt.merchantUniquePaymentId;
  }

  /// Returns the stored attempt for [merchantUniquePaymentId], or `null`.
  CheckoutAttempt? getByMerchantPaymentId(String merchantUniquePaymentId) =>
      _byMerchantPaymentId[merchantUniquePaymentId];

  /// Returns the stored attempt originally created with idempotency [key],
  /// or `null`.
  CheckoutAttempt? getByIdempotencyKey(String key) {
    final id = _byIdempotencyKey[key];
    return id == null ? null : _byMerchantPaymentId[id];
  }

  /// Removes every attempt created before [cutoff]. Returns the count removed.
  int purgeCreatedBefore(DateTime cutoff) {
    var removed = 0;
    for (final attempt in _byMerchantPaymentId.values.toList()) {
      if (attempt.createdAt.isBefore(cutoff)) {
        _byMerchantPaymentId.remove(attempt.merchantUniquePaymentId);
        _byIdempotencyKey.remove(attempt.idempotencyKey);
        removed += 1;
      }
    }
    return removed;
  }

  /// Throws [AttemptStoreError] `'CHECKOUT_ATTEMPT_NOT_FOUND'` if no attempt
  /// exists for [merchantUniquePaymentId].
  CheckoutAttempt replace(
    String merchantUniquePaymentId,
    CheckoutAttempt next,
  ) {
    if (!_byMerchantPaymentId.containsKey(merchantUniquePaymentId)) {
      throw AttemptStoreError('CHECKOUT_ATTEMPT_NOT_FOUND');
    }
    _byMerchantPaymentId[merchantUniquePaymentId] = next;
    return next;
  }
}
