/// Fixture-based tests for the pure halves of `new_demo_app.dart` and
/// `verify_demo_app.dart` — name validation, idempotent workspace insertion,
/// port selection, and the `reserveLaunch()` ordering heuristic.
///
/// Run directly (these scripts are not a package, so `melos run test` does not
/// reach them):
///
/// ```bash
/// dart test .claude/skills/zenpay-demo-app/scripts/new_demo_app_test.dart
/// ```
library;

import 'dart:io';

import 'package:test/test.dart';

import 'new_demo_app.dart' show addWorkspaceEntries, buildParser, pickPort, readEnv, removeWorkspaceEntries, validateName;
import 'verify_demo_app.dart' show checkReserveOrdering;

const _pubspec = '''
name: zp_flutter_sdk

workspace:
  - zenpay_dart
  - zenpay_flutter

dev_dependencies:
  melos: ^8.3.0
''';

void main() {
  group('validateName', () {
    test('accepts snake_case', () {
      expect(validateName('coffee_shop'), isNull);
    });

    test('rejects empty, kebab-case, leading digits and reserved names', () {
      expect(validateName(''), isNotNull);
      expect(validateName('coffee-shop'), isNotNull);
      expect(validateName('2coffee'), isNotNull);
      expect(validateName('app'), isNotNull);
      expect(validateName('backend'), isNotNull);
    });
  });

  group('addWorkspaceEntries', () {
    test('appends after the last existing member', () {
      final result = addWorkspaceEntries(_pubspec, ['example/coffee_app']);
      expect(result, contains('  - zenpay_flutter\n  - example/coffee_app\n'));
      expect(result, contains('dev_dependencies:'));
    });

    test('is idempotent — a duplicate member breaks pub get outright', () {
      final once = addWorkspaceEntries(_pubspec, ['example/coffee_app']);
      expect(addWorkspaceEntries(once, ['example/coffee_app']), once);
    });

    test('adds only the missing members of a mixed list', () {
      final result = addWorkspaceEntries(_pubspec, ['zenpay_dart', 'example/coffee_backend']);
      expect('zenpay_dart'.allMatches(result).length, 1);
      expect(result, contains('example/coffee_backend'));
    });

    test('throws when there is no workspace list to extend', () {
      expect(() => addWorkspaceEntries('name: nope\n', ['x']), throwsFormatException);
    });
  });

  group('removeWorkspaceEntries', () {
    test('round-trips with addWorkspaceEntries', () {
      final added = addWorkspaceEntries(_pubspec, ['example/coffee_app', 'example/coffee_backend']);
      expect(removeWorkspaceEntries(added, ['example/coffee_app', 'example/coffee_backend']), _pubspec);
    });

    test('leaves unrelated members and the rest of the file alone', () {
      final result = removeWorkspaceEntries(_pubspec, ['example/never_added']);
      expect(result, _pubspec);
    });

    test('removes only the named member', () {
      final added = addWorkspaceEntries(_pubspec, ['example/a_app', 'example/b_app']);
      final result = removeWorkspaceEntries(added, ['example/a_app']);
      expect(result, isNot(contains('example/a_app')));
      expect(result, contains('example/b_app'));
      expect(result, contains('zenpay_dart'));
    });
  });

  group('pickPort', () {
    test('claims the first free port above the reference example', () {
      final root = Directory.systemTemp.createTempSync('zenpay_port_test');
      addTearDown(() => root.deleteSync(recursive: true));

      expect(pickPort(root.path), 7100);

      Directory('${root.path}/example/one').createSync(recursive: true);
      File('${root.path}/example/one/.env').writeAsStringSync('PORT=7100\n');
      expect(pickPort(root.path), 7101);
    });
  });

  group('readEnv', () {
    test('skips comments and blanks, keeps values containing "="', () {
      final file = File('${Directory.systemTemp.createTempSync('zenpay_env_test').path}/.env')..writeAsStringSync('# comment\n\nA=1\nB=x=y\n');
      addTearDown(() => file.parent.deleteSync(recursive: true));

      expect(readEnv(file.path), {'A': '1', 'B': 'x=y'});
    });

    test('returns empty for a missing file', () {
      expect(readEnv('/definitely/not/here/.env'), isEmpty);
    });
  });

  group('checkReserveOrdering', () {
    /// Writes [source] to a throwaway .dart file and returns it.
    File source(String source) {
      final dir = Directory.systemTemp.createTempSync('zenpay_order_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      return File('${dir.path}/page.dart')..writeAsStringSync(source);
    }

    test('passes when reserveLaunch is the first statement', () {
      final file = source('''
Future<void> _pay() async {
  if (!_checkout.reserveLaunch()) return;
  final token = await prepareCheckout();
}
''');
      expect(checkReserveOrdering([file]).passed, isTrue);
    });

    test('fails when a backend call is awaited first — the real popup bug', () {
      final file = source('''
Future<void> _pay() async {
  final token = await prepareCheckout();
  if (!_checkout.reserveLaunch()) return;
}
''');
      final result = checkReserveOrdering([file]);
      expect(result.passed, isFalse);
      expect(result.detail, contains('popup'));
    });

    test('fails when reserveLaunch is missing entirely', () {
      expect(checkReserveOrdering([source('void main() {}\n')]).passed, isFalse);
    });
  });

  test('buildParser defaults to full-stack mode', () {
    expect(buildParser().parse(['--name', 'x']).option('mode'), 'full');
  });
}
