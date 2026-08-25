/// Tests for `checkout_errors.dart`'s sealed `ZpCheckoutException`
/// hierarchy's `toString()` output.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/zenpay_checkout.dart';

void main() {
  test('ZpCheckoutAlreadyActiveException.toString embeds its message', () {
    expect(const ZpCheckoutAlreadyActiveException().toString(), 'ZpCheckoutAlreadyActiveException: A ZenPay checkout is already active.');
  });

  test('ZpCheckoutDisposedException.toString embeds its message', () {
    expect(const ZpCheckoutDisposedException().toString(), 'ZpCheckoutDisposedException: The ZenPay checkout controller is disposed.');
  });

  test('ZpInvalidLaunchException.toString embeds its custom message', () {
    expect(const ZpInvalidLaunchException('host not allowlisted').toString(), 'ZpInvalidLaunchException: host not allowlisted');
  });
}
