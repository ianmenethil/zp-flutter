/// Fixture-based tests for `cli.dart`'s pure helpers.
///
/// Only the seams that can be driven without a stdin prompt or a live tool
/// are covered: `.env` upsert, token-secret generation, keytool resolution,
/// and reading the Android `applicationId`. Those four are public in
/// `cli.dart` specifically so tests can reach them without going through
/// `main` (which calls `exit`) — the same arrangement
/// `scripts/apply_platform_config.dart` uses.
///
/// Run directly — `melos run test` filters on packages with a `test/`
/// directory, and the repo root has none:
///
/// ```bash
/// dart test cli_test.dart
/// ```
library;

import 'dart:io';

import 'package:test/test.dart';

import 'cli.dart' show androidApplicationId, envValuePattern, generateTokenSecret, keytoolCandidates, resolveKeytool, upsertEnvValue;

const _env = '''
PORT=7000

# A comment
TOKEN_SECRET=
ZENPAY_API_KEY=existing-key
''';

void main() {
  group('upsertEnvValue', () {
    test('replaces an existing value in place', () {
      final result = upsertEnvValue(_env, 'ZENPAY_API_KEY', 'new-key');
      expect(result, contains('ZENPAY_API_KEY=new-key'));
      expect(result, isNot(contains('existing-key')));
      expect(result, contains('PORT=7000'));
      expect(result, contains('# A comment'));
    });

    test('fills a key the template left blank', () {
      expect(upsertEnvValue(_env, 'TOKEN_SECRET', 'abc'), contains('TOKEN_SECRET=abc'));
    });

    test('appends a key the template never carried', () {
      final result = upsertEnvValue(_env, 'BRAND_NEW', 'value');
      expect(result, endsWith('BRAND_NEW=value\n'));
      expect(result, contains('PORT=7000'));
    });

    test('does not match a key that is merely a prefix of another', () {
      // ZENPAY_API_KEY must not be found when looking for ZENPAY_API.
      expect(envValuePattern('ZENPAY_API').hasMatch(_env), isFalse);
    });
  });

  group('generateTokenSecret', () {
    test('is 64 lowercase hex chars — 32 bytes, as .env.example documents', () {
      expect(generateTokenSecret(), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('differs every call', () {
      expect(generateTokenSecret(), isNot(generateTokenSecret()));
    });
  });

  group('resolveKeytool', () {
    test('returns null when no candidate exists and keytool is not on PATH', () {
      // The branch that cannot be reached on a machine with a JDK installed:
      // injecting the candidate list is the only way to exercise the
      // warn-and-continue path in _ensureAppLinks.
      final result = resolveKeytool(candidates: ['/definitely/not/here/keytool']);
      expect(result, anyOf(isNull, equals(Platform.isWindows ? 'keytool.exe' : 'keytool')));
    });

    test('returns the first candidate that exists', () {
      final dir = Directory.systemTemp.createTempSync('zenpay_keytool_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final present = File('${dir.path}/keytool')..writeAsStringSync('');

      expect(resolveKeytool(candidates: ['/nope/keytool', present.path]), present.path);
    });

    test('checks JAVA_HOME before the bundled Android Studio runtime', () {
      final candidates = keytoolCandidates();
      if (Platform.environment['JAVA_HOME'] == null) {
        return; // Nothing to order against on this machine.
      }
      expect(candidates.first, contains('bin'));
      expect(candidates.first, startsWith(Platform.environment['JAVA_HOME']!));
    });
  });

  group('androidApplicationId', () {
    /// Builds a fake repo root with [gradle] at the app module path.
    String fixture(String fileName, String gradle) {
      final dir = Directory.systemTemp.createTempSync('zenpay_gradle_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/example/app/android/app/$fileName')
        ..createSync(recursive: true)
        ..writeAsStringSync(gradle);
      return dir.path;
    }

    test('reads the Kotlin DSL form', () {
      final root = fixture('build.gradle.kts', 'android {\n  defaultConfig {\n    applicationId = "com.example.demo"\n  }\n}\n');
      expect(androidApplicationId(root), 'com.example.demo');
    });

    test('reads the Groovy form, which uses no equals sign', () {
      final root = fixture('build.gradle', "android {\n  defaultConfig {\n    applicationId 'com.example.groovy'\n  }\n}\n");
      expect(androidApplicationId(root), 'com.example.groovy');
    });

    test('returns null when there is no Android project', () {
      final dir = Directory.systemTemp.createTempSync('zenpay_gradle_empty');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(androidApplicationId(dir.path), isNull);
    });

    test('reads this repoʼs real example app', () {
      expect(androidApplicationId(Directory.current.path), 'au.com.zenithpayments.zenpay_example_app');
    });
  });
}
