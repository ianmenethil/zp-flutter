// Patches the generated Android/iOS host projects with App Link / Universal
// Link configuration for a given host.
//
// Run it after `flutter create` regenerates the platform folders, and whenever
// the return host changes:
//
//   dart run scripts/apply_platform_config.dart --host payments.yourmerchant.com
//
// It exists so the host is never hardcoded in a committed manifest, and so the
// config survives platform folders being regenerated. Idempotent: re-running
// against the same host changes nothing.
import 'dart:io';

import 'package:args/args.dart';

const _defaultPath = '/zenpay/app-return';

/// Builds the `--host`/`--root`/`--path` parser. A top-level function so
/// tests can exercise parsing without invoking [main] (which calls [exit]).
ArgParser buildParser() => ArgParser()
  ..addOption(
    'host',
    help: 'The App Link / Universal Link host, e.g. payments.example.com.',
    mandatory: true,
  )
  ..addOption(
    'root',
    help: 'Repo root containing example/app. Defaults to the current directory.',
  )
  ..addOption('path', help: 'App Link path prefix.', defaultsTo: _defaultPath)
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this usage.');

void main(List<String> arguments) {
  final parser = buildParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln(parser.usage);
    exit(64);
  }

  if (results['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  // `mandatory: true` only auto-throws during parse() if the option also has
  // a callback; without one it silently defers to a later ArgumentError. So
  // this is checked explicitly rather than relied on.
  if (!results.wasParsed('host')) {
    stderr
      ..writeln('Missing required option: --host')
      ..writeln(parser.usage);
    exit(64);
  }

  final root = results['root'] as String? ?? Directory.current.path;
  final host = results['host'] as String;
  final path = results['path'] as String;
  if (!path.startsWith('/')) {
    stderr.writeln("--path must begin with '/'.");
    exit(1);
  }
  patchAndroid(root, host, path);
  patchIos(root, host);
  stdout.writeln('Applied App Link config for $host$path.');
}

/// Patches `AndroidManifest.xml` with the App Link intent filter. Public so
/// tests can call it directly against a temp directory.
void patchAndroid(String root, String host, String path) {
  final manifest = File(
    '$root/example/app/android/app/src/main/AndroidManifest.xml',
  );
  if (!manifest.existsSync()) {
    stderr.writeln('Android manifest not found: ${manifest.path}');
    exit(1);
  }

  final text = manifest.readAsStringSync();

  // Already patched: rewrite the host/path in place. Returning early here
  // instead would make the host permanently unchangeable after the first run,
  // which is the opposite of why this script exists.
  final existing = RegExp(
    r'<data\s+android:scheme="https"\s+android:host="[^"]*"\s+android:pathPrefix="[^"]*"\s*/>',
  );
  if (existing.hasMatch(text)) {
    manifest.writeAsStringSync(
      text.replaceAll(
        existing,
        '<data\n                    android:scheme="https"\n'
        '                    android:host="$host"\n'
        '                    android:pathPrefix="$path" />',
      ),
    );
    return;
  }

  final snippet =
      '''

            <!-- The SDK's AppLinksReturnUriSource (app_links) owns the checkout
                 return; Flutter's built-in handler must stay off or both
                 compete for the same URI. -->
            <meta-data
                android:name="flutter_deeplinking_enabled"
                android:value="false" />

            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:scheme="https"
                    android:host="$host"
                    android:pathPrefix="$path" />
            </intent-filter>
''';

  const marker = '</activity>';
  if (!text.contains(marker)) {
    stderr.writeln('Unable to locate Android activity closing tag.');
    exit(1);
  }
  manifest.writeAsStringSync(
    text.replaceFirst(marker, '$snippet        $marker'),
  );
}

/// Patches the iOS Runner project with entitlements and deep-link config.
/// Public so tests can call it directly against a temp directory.
void patchIos(String root, String host) {
  final runnerDir = Directory('$root/example/app/ios/Runner');
  final project = File(
    '$root/example/app/ios/Runner.xcodeproj/project.pbxproj',
  );
  if (!runnerDir.existsSync() || !project.existsSync()) {
    stderr.writeln('Generated iOS Runner project not found.');
    exit(1);
  }

  File('${runnerDir.path}/Runner.entitlements').writeAsStringSync(
    '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Must equal the host serving /.well-known/apple-app-site-association. -->
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:$host</string>
  </array>
</dict>
</plist>
''',
  );

  final infoPlist = File('${runnerDir.path}/Info.plist');
  var infoText = infoPlist.readAsStringSync();
  if (!infoText.contains('FlutterDeepLinkingEnabled')) {
    const marker = '</dict>';
    if (!infoText.contains(marker)) {
      stderr.writeln('Unable to locate iOS Info.plist dict closing tag.');
      exit(1);
    }
    infoText = infoText.replaceFirst(
      marker,
      '\t<key>FlutterDeepLinkingEnabled</key>\n\t<false/>\n$marker',
    );
    infoPlist.writeAsStringSync(infoText);
  }

  var projectText = project.readAsStringSync();
  if (!projectText.contains(
    'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
  )) {
    // The negative lookahead keeps this off the RunnerTests target, which has
    // its own bundle identifier and must not be signed with the app's
    // entitlements.
    projectText = projectText.replaceAllMapped(
      RegExp(r'(\n\s+PRODUCT_BUNDLE_IDENTIFIER = (?!.*RunnerTests)[^;]+;)'),
      (m) => '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;${m[1]}',
    );
    project.writeAsStringSync(projectText);
  }
}
