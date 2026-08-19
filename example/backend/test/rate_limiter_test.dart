/// Unit tests for [FixedWindowRateLimiter] — the mechanism backing every
/// rate-limited route (`/checkout/token`, `/checkout/exchange`,
/// `/api/v1/callbacks`).
library;

import 'package:test/test.dart';
import 'package:zenpay_example_backend/src/rate_limiter.dart';

void main() {
  test('allows requests up to the limit, then rejects the next one', () {
    final limiter = FixedWindowRateLimiter(3, const Duration(seconds: 60));
    final now = DateTime.utc(2026);

    expect(limiter.allow('ip-1', now), isTrue);
    expect(limiter.allow('ip-1', now), isTrue);
    expect(limiter.allow('ip-1', now), isTrue);
    expect(limiter.allow('ip-1', now), isFalse);
  });

  test('allows again once the window has reset', () {
    final limiter = FixedWindowRateLimiter(1, const Duration(seconds: 60));
    final now = DateTime.utc(2026);

    expect(limiter.allow('ip-1', now), isTrue);
    expect(limiter.allow('ip-1', now), isFalse);
    expect(limiter.allow('ip-1', now.add(const Duration(seconds: 61))), isTrue);
  });

  test('tracks each key independently', () {
    final limiter = FixedWindowRateLimiter(1, const Duration(seconds: 60));
    final now = DateTime.utc(2026);

    expect(limiter.allow('ip-1', now), isTrue);
    expect(limiter.allow('ip-2', now), isTrue);
    expect(limiter.allow('ip-1', now), isFalse);
    expect(limiter.allow('ip-2', now), isFalse);
  });
}
