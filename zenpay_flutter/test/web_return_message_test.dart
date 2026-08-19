import 'package:flutter_test/flutter_test.dart';
import 'package:zenpay_flutter/src/return_handling/web_return_message.dart';

void main() {
  group('encodeZpReturnMessage / decodeZpReturnMessage', () {
    test('decode unwraps what encode wrapped', () {
      const href = 'https://app.example.com/return?t=abc123';
      expect(decodeZpReturnMessage(encodeZpReturnMessage(href)), href);
    });

    test('decode returns null for an unrelated message', () {
      expect(decodeZpReturnMessage('some-other-message'), isNull);
    });

    test('decode returns null for an empty string', () {
      expect(decodeZpReturnMessage(''), isNull);
    });
  });
}
