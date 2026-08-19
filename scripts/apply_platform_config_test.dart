import 'dart:io';

import 'package:test/test.dart';

import 'apply_platform_config.dart';

const _androidManifestFresh = '''
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity android:name=".MainActivity">
        </activity>
    </application>
</manifest>
''';

const _infoPlist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Runner</string>
</dict>
</plist>
''';

const _projectPbxproj = '''
		97C147061CF9000F007C117D /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_BUNDLE_IDENTIFIER = com.example.zenpayExampleApp;
			};
			name = Debug;
		};
		97C147071CF9000F007C117E /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				PRODUCT_BUNDLE_IDENTIFIER = com.example.zenpayExampleApp.RunnerTests;
			};
			name = Debug;
		};
''';

void main() {
  group('buildParser', () {
    test('does not mark --host parsed when omitted', () {
      // package:args only auto-throws a mandatory option's absence during
      // parse() if the option also has a callback; main() checks
      // wasParsed('host') explicitly instead, so that is what this protects.
      final results = buildParser().parse([]);
      expect(results.wasParsed('host'), isFalse);
    });

    test('accepts --host and defaults --path', () {
      final results = buildParser().parse(['--host', 'payments.example.com']);
      expect(results.wasParsed('host'), isTrue);
      expect(results['host'], 'payments.example.com');
      expect(results['path'], '/zenpay/app-return');
      expect(results['root'], isNull);
    });
  });

  group('patchAndroid', () {
    late Directory root;
    late File manifest;

    setUp(() {
      root = Directory.systemTemp.createTempSync('apply_platform_config_');
      manifest = File(
        '${root.path}/example/app/android/app/src/main/AndroidManifest.xml',
      )..createSync(recursive: true);
      manifest.writeAsStringSync(_androidManifestFresh);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('inserts the App Link intent filter into a fresh manifest', () {
      patchAndroid(root.path, 'payments.example.com', '/zenpay/app-return');

      final text = manifest.readAsStringSync();
      expect(text, contains('android:host="payments.example.com"'));
      expect(text, contains('android:pathPrefix="/zenpay/app-return"'));
      expect(text, contains('flutter_deeplinking_enabled'));
    });

    test('re-running with a different host rewrites in place', () {
      patchAndroid(root.path, 'old.example.com', '/zenpay/app-return');
      patchAndroid(root.path, 'new.example.com', '/zenpay/app-return');

      final text = manifest.readAsStringSync();
      expect(text, isNot(contains('old.example.com')));
      expect(text, contains('android:host="new.example.com"'));
      // Idempotent: exactly one intent-filter, not one appended per run.
      expect('<intent-filter'.allMatches(text).length, 1);
    });
  });

  group('patchIos', () {
    late Directory root;
    late Directory runnerDir;
    late File infoPlist;
    late File project;

    setUp(() {
      root = Directory.systemTemp.createTempSync('apply_platform_config_');
      runnerDir = Directory('${root.path}/example/app/ios/Runner')
        ..createSync(recursive: true);
      infoPlist = File('${runnerDir.path}/Info.plist')
        ..writeAsStringSync(_infoPlist);
      project =
          File('${root.path}/example/app/ios/Runner.xcodeproj/project.pbxproj')
            ..createSync(recursive: true)
            ..writeAsStringSync(_projectPbxproj);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes entitlements with the given host', () {
      patchIos(root.path, 'payments.example.com');

      final entitlements = File(
        '${runnerDir.path}/Runner.entitlements',
      ).readAsStringSync();
      expect(entitlements, contains('applinks:payments.example.com'));
    });

    test('adds FlutterDeepLinkingEnabled to Info.plist once', () {
      patchIos(root.path, 'payments.example.com');
      patchIos(root.path, 'payments.example.com');

      final text = infoPlist.readAsStringSync();
      expect('FlutterDeepLinkingEnabled'.allMatches(text).length, 1);
    });

    test(
      'adds CODE_SIGN_ENTITLEMENTS to the app target but not RunnerTests',
      () {
        patchIos(root.path, 'payments.example.com');

        final text = project.readAsStringSync();
        expect('CODE_SIGN_ENTITLEMENTS'.allMatches(text).length, 1);
        expect(
          text.indexOf('CODE_SIGN_ENTITLEMENTS'),
          lessThan(text.indexOf('RunnerTests')),
        );
      },
    );
  });
}
