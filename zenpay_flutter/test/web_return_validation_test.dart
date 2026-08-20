import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/src/return_handling/web/web_return_validation.dart';

void main() {
  group('parseIncomingReturnMessage', () {
    const expectedOrigin = 'https://app.example.com';

    test('rejects a message from a different origin', () {
      final result = parseIncomingReturnMessage(
        eventOrigin: 'https://attacker.example.com',
        expectedOrigin: expectedOrigin,
        messageData: 'zenpay:checkout-return:https://app.example.com/return?t=abc',
      );
      expect(result, isNull);
    });

    test('rejects a null message', () {
      final result = parseIncomingReturnMessage(
        eventOrigin: expectedOrigin,
        expectedOrigin: expectedOrigin,
        messageData: null,
      );
      expect(result, isNull);
    });

    test('rejects a message that is not a return handoff', () {
      final result = parseIncomingReturnMessage(
        eventOrigin: expectedOrigin,
        expectedOrigin: expectedOrigin,
        messageData: 'some-other-message',
      );
      expect(result, isNull);
    });

    test('rejects a return handoff with a malformed href', () {
      final result = parseIncomingReturnMessage(
        eventOrigin: expectedOrigin,
        expectedOrigin: expectedOrigin,
        messageData: 'zenpay:checkout-return:http://example.com:notaport/path',
      );
      expect(result, isNull);
    });

    test('accepts a same-origin, well-formed return handoff', () {
      final result = parseIncomingReturnMessage(
        eventOrigin: expectedOrigin,
        expectedOrigin: expectedOrigin,
        messageData: 'zenpay:checkout-return:https://app.example.com/return?t=abc123',
      );
      expect(result, Uri.parse('https://app.example.com/return?t=abc123'));
    });
  });

  group('matchesReturnAddress', () {
    final expected = Uri.parse('https://app.example.com/return');

    test('matches an identical address', () {
      expect(matchesReturnAddress(Uri.parse('https://app.example.com/return'), expected), isTrue);
    });

    test('scheme and host compare case-insensitively', () {
      expect(matchesReturnAddress(Uri.parse('HTTPS://APP.EXAMPLE.COM/return'), expected), isTrue);
    });

    test('rejects a different scheme', () {
      expect(matchesReturnAddress(Uri.parse('http://app.example.com/return'), expected), isFalse);
    });

    test('rejects a different host', () {
      expect(matchesReturnAddress(Uri.parse('https://evil.example.com/return'), expected), isFalse);
    });

    test('rejects a different path', () {
      expect(matchesReturnAddress(Uri.parse('https://app.example.com/other'), expected), isFalse);
    });

    test('rejects a different port', () {
      expect(matchesReturnAddress(Uri.parse('https://app.example.com:8443/return'), expected), isFalse);
    });
  });
}
