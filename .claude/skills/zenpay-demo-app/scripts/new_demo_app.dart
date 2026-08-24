/// Scaffolds a ZenPay Hosted Checkout demo — a Shelf backend using
/// `zenpay_dart` and a Flutter client using `zenpay_flutter` — as flat
/// workspace members under `example/`.
///
/// Owns only the mechanical half of a demo: package creation via the standard
/// `flutter create` / `dart create` tooling, workspace registration, `.env`
/// seeding, and port selection. It writes no product code and no checkout
/// logic — that is the model's job, guided by the skill's `references/`.
///
/// Run from the repository root:
///
/// ```bash
/// dart run .claude/skills/zenpay-demo-app/scripts/new_demo_app.dart --name coffee_shop
/// ```
library;

import 'dart:io';

import 'package:args/args.dart';

/// Lowest port a generated backend may claim. `example/backend` owns 7000 and
/// `cli.dart --web` serves the example app on 7001, so demos start above both.
const _firstDemoPort = 7100;

/// Package-name rule: snake_case, letters first, as `dart pub` requires.
final _namePattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Reserved names that would collide with the reference integration.
const _reservedNames = <String>{'app', 'backend', 'example'};

/// Builds the argument parser.
///
/// Top-level so tests can exercise parsing without invoking [main], which
/// calls [exit].
ArgParser buildParser() => ArgParser()
  ..addOption('name', help: 'Demo name in snake_case, e.g. coffee_shop.')
  ..addOption('mode', allowed: ['full', 'client'], defaultsTo: 'full', help: 'full = backend + app; client = app only.')
  ..addOption('root', help: 'Repository root. Defaults to the current directory.')
  ..addOption('port', help: 'Backend port. Defaults to the first free port from $_firstDemoPort.')
  ..addFlag('committed', negatable: false, help: 'Also emit a CLAUDE.md per package, so the tree passes check_claude_md.dart.')
  ..addFlag('remove', negatable: false, help: 'Delete the named demo and unregister it from the root pub workspace.')
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Print usage.');

/// Returns why [name] is unusable as a demo name, or null when it is fine.
String? validateName(String name) {
  if (name.isEmpty) return 'A --name is required.';
  if (!_namePattern.hasMatch(name)) return 'Name must be snake_case starting with a letter: got "$name".';
  if (_reservedNames.contains(name)) return 'Name "$name" collides with the reference integration.';
  return null;
}

/// Inserts [entries] into [pubspecText]'s `workspace:` list, preserving order
/// and skipping any already present.
///
/// Idempotent by design: re-running the scaffold after a partial failure must
/// not produce duplicate members, which `dart pub get` rejects outright.
String addWorkspaceEntries(String pubspecText, List<String> entries) {
  final lines = pubspecText.split('\n');
  final start = lines.indexWhere((line) => line.trimRight() == 'workspace:');
  if (start == -1) throw const FormatException('Root pubspec.yaml has no `workspace:` list.');

  var end = start + 1;
  while (end < lines.length && lines[end].startsWith('  - ')) {
    end++;
  }

  final existing = lines.sublist(start + 1, end).map((line) => line.trim().substring(2).trim()).toSet();
  final additions = entries.where((entry) => !existing.contains(entry)).map((entry) => '  - $entry').toList();
  if (additions.isEmpty) return pubspecText;

  return <String>[...lines.sublist(0, end), ...additions, ...lines.sublist(end)].join('\n');
}

/// Drops [entries] from [pubspecText]'s `workspace:` list, leaving the rest
/// untouched.
///
/// The inverse of [addWorkspaceEntries]. A demo that cannot be removed is not
/// really throwaway — and a stale member left behind fails `dart pub get` for
/// the entire monorepo, not just the demo.
String removeWorkspaceEntries(String pubspecText, List<String> entries) {
  final lines = pubspecText.split('\n');
  final start = lines.indexWhere((line) => line.trimRight() == 'workspace:');
  if (start == -1) throw const FormatException('Root pubspec.yaml has no `workspace:` list.');

  var end = start + 1;
  while (end < lines.length && lines[end].startsWith('  - ')) {
    end++;
  }

  final kept = lines.sublist(start + 1, end).where((line) => !entries.contains(line.trim().substring(2).trim()));
  return <String>[...lines.sublist(0, start + 1), ...kept, ...lines.sublist(end)].join('\n');
}

/// The lowest port at or above [_firstDemoPort] that no `example/*/.env`
/// already claims, so a demo backend never collides with a running one.
int pickPort(String root) {
  final claimed = <int>{};
  final exampleDir = Directory('$root/example');
  if (exampleDir.existsSync()) {
    for (final entry in exampleDir.listSync().whereType<Directory>()) {
      final env = File('${entry.path}/.env');
      if (!env.existsSync()) continue;
      for (final line in env.readAsLinesSync()) {
        final match = RegExp(r'^PORT=(\d+)').firstMatch(line.trim());
        final port = match == null ? null : int.tryParse(match.group(1)!);
        if (port != null) claimed.add(port);
      }
    }
  }

  var port = _firstDemoPort;
  while (claimed.contains(port)) {
    port++;
  }
  return port;
}

/// Reads `KEY=value` pairs out of [path], ignoring comments and blanks.
Map<String, String> readEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return const <String, String>{};

  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final split = trimmed.indexOf('=');
    if (split > 0) values[trimmed.substring(0, split)] = trimmed.substring(split + 1);
  }
  return values;
}

/// Runs [executable] with [arguments] in [workingDirectory], exiting on failure.
void _run(String executable, List<String> arguments, {required String workingDirectory}) {
  final result = Process.runSync(executable, arguments, workingDirectory: workingDirectory, runInShell: true);
  if (result.exitCode != 0) {
    stderr
      ..writeln('FAILED: $executable ${arguments.join(' ')}')
      ..writeln(result.stdout)
      ..writeln(result.stderr);
    exit(result.exitCode);
  }
}

/// Adds `resolution: workspace` and the SDK dependency to a generated
/// `pubspec.yaml`, and strips the `dependency_overrides` block if the
/// generator emitted one — an override defeats workspace resolution.
void _patchPubspec(String path, {required String sdkDependency, required String sdkConstraint}) {
  final file = File(path);
  final text = file.readAsStringSync();
  if (text.contains('resolution: workspace')) return;

  final patched = text.replaceFirst(
    RegExp('^environment:', multiLine: true),
    'resolution: workspace\n\nenvironment:',
  );
  final withDependency = patched.replaceFirst(
    RegExp(r'^dependencies:$', multiLine: true),
    'dependencies:\n  $sdkDependency: $sdkConstraint',
  );
  file.writeAsStringSync(withDependency);
}

/// Writes [contents] to [path], creating parent directories as needed.
void _write(String path, String contents) => File(path)
  ..createSync(recursive: true)
  ..writeAsStringSync(contents);

/// Entrypoint. Validates arguments, then scaffolds both packages.
void main(List<String> arguments) {
  final parser = buildParser();
  final args = parser.parse(arguments);

  if (args.flag('help')) {
    stdout.writeln('Scaffold a ZenPay demo app.\n\n${parser.usage}');
    return;
  }

  final name = args.option('name') ?? '';
  final nameError = validateName(name);
  if (nameError != null) {
    stderr.writeln('$nameError\n\n${parser.usage}');
    exit(64);
  }

  final root = args.option('root') ?? Directory.current.path;
  if (!File('$root/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml at "$root" — run this from the repository root, or pass --root.');
    exit(64);
  }

  final fullStack = args.option('mode') == 'full';
  final appDir = '$root/example/${name}_app';
  final backendDir = '$root/example/${name}_backend';

  if (args.flag('remove')) {
    _remove(root, name, appDir: appDir, backendDir: backendDir);
    return;
  }

  for (final dir in [appDir, if (fullStack) backendDir]) {
    if (Directory(dir).existsSync()) {
      stderr.writeln('"$dir" already exists. Pick another --name, or delete it first.');
      exit(70);
    }
  }

  final port = int.tryParse(args.option('port') ?? '') ?? pickPort(root);
  final reference = readEnv('$root/example/backend/.env');
  final referenceApp = readEnv('$root/example/app/.env');
  final backendBaseUrl = fullStack ? 'http://localhost:$port' : (referenceApp['BACKEND_BASE_URL'] ?? 'http://localhost:7000');

  stdout.writeln('Scaffolding "$name" (${fullStack ? 'full stack' : 'client only'}) on port $port...');

  // Standard tooling generates the packages; this script only patches what the
  // workspace requires on top. Hand-rolling a Flutter project's android/ and
  // web/ folders is exactly the kind of thing `flutter create` exists for.
  _run('flutter', ['create', '--project-name', '${name}_app', '--platforms', 'android,web', '--no-pub', appDir], workingDirectory: root);
  _patchPubspec('$appDir/pubspec.yaml', sdkDependency: 'zenpay_flutter', sdkConstraint: '^0.1.0');
  _write('$appDir/.env', _appEnv(backendBaseUrl: backendBaseUrl, reference: reference, referenceApp: referenceApp));
  _write('$appDir/.env.example', _appEnv(backendBaseUrl: backendBaseUrl, reference: const {}, referenceApp: const {}));

  if (fullStack) {
    _run('dart', ['create', '-t', 'console', '--no-pub', '--force', backendDir], workingDirectory: root);
    _patchPubspec('$backendDir/pubspec.yaml', sdkDependency: 'zenpay_dart', sdkConstraint: '^0.1.0');
    _write('$backendDir/.env', _backendEnv(port: port, reference: reference));
    _write('$backendDir/.env.example', _backendEnv(port: port, reference: const {}));
  }

  final rootPubspec = File('$root/pubspec.yaml');
  rootPubspec.writeAsStringSync(
    addWorkspaceEntries(rootPubspec.readAsStringSync(), [
      'example/${name}_app',
      if (fullStack) 'example/${name}_backend',
    ]),
  );

  if (args.flag('committed')) {
    _write('$appDir/CLAUDE.md', _claudeMdStub('${name}_app', 'Flutter client for the $name demo.'));
    if (fullStack) _write('$backendDir/CLAUDE.md', _claudeMdStub('${name}_backend', 'Merchant backend for the $name demo.'));
    stdout.writeln('Wrote CLAUDE.md stubs — add an entry per source file as you write them, or check_claude_md.dart will fail.');
  }

  stdout
    ..writeln('\nScaffolded:')
    ..writeln('  $appDir')
    ..writeln(fullStack ? '  $backendDir' : '  (client mode — using the existing example/backend)')
    ..writeln('\nNext:')
    ..writeln('  melos bs')
    ..writeln('\nThen write the product code. Read, in order:')
    ..writeln('  .claude/skills/zenpay-demo-app/references/integration-contract.md')
    ..writeln(fullStack ? '  .claude/skills/zenpay-demo-app/references/backend-wiring.md' : '')
    ..writeln('  .claude/skills/zenpay-demo-app/references/client-wiring.md');

  if (fullStack && (reference['ZENPAY_API_KEY'] ?? '').isEmpty) {
    stdout.writeln('\nNOTE: example/backend/.env had no ZenPay credentials to copy. Fill them into $backendDir/.env before running.');
  }
}

/// Deletes a generated demo and unregisters it from the root pub workspace.
///
/// Refuses when neither directory exists rather than silently "succeeding" —
/// a typo'd name should not look like a completed removal.
void _remove(String root, String name, {required String appDir, required String backendDir}) {
  final present = [appDir, backendDir].where((dir) => Directory(dir).existsSync()).toList();
  if (present.isEmpty) {
    stderr.writeln('No demo named "$name" under $root/example. Nothing removed.');
    exit(70);
  }

  for (final dir in present) {
    Directory(dir).deleteSync(recursive: true);
    stdout.writeln('Deleted $dir');
  }

  final rootPubspec = File('$root/pubspec.yaml');
  rootPubspec.writeAsStringSync(
    removeWorkspaceEntries(rootPubspec.readAsStringSync(), ['example/${name}_app', 'example/${name}_backend']),
  );

  stdout.writeln('Unregistered from the root workspace. Run `melos bs` to re-resolve.');
}

/// The generated app's `.env`, seeded from the reference example when present.
String _appEnv({required String backendBaseUrl, required Map<String, String> reference, required Map<String, String> referenceApp}) =>
    '''
# Read via --dart-define-from-file=.env.
BACKEND_BASE_URL=$backendBaseUrl

# Must match the backend's ZENPAY_ALLOWED_CHECKOUT_HOSTS exactly.
ALLOWED_CHECKOUT_HOSTS=${reference['ZENPAY_ALLOWED_CHECKOUT_HOSTS'] ?? 'pay.sandbox.travelpay.com.au'}

# Compared exactly by the SDK — scheme, host, port and path must match the
# backend's own return URI, or the return is rejected rather than ignored.
APP_RETURN_URI_WEB=${reference['APP_RETURN_URI_WEB'] ?? 'https://localhost:3000/'}

# A public https host serving /.well-known/, never localhost: the OS fetches
# those files from the internet to verify the App Link.
APP_RETURN_URI_MOBILE=${referenceApp['APP_RETURN_URI_MOBILE'] ?? 'https://payments.example.com/zenpay/app-return'}
''';

/// The generated backend's `.env`, seeded from the reference example.
String _backendEnv({required int port, required Map<String, String> reference}) =>
    '''
PORT=$port

# Public https address of THIS server. ZenPay's callback is server-to-server
# and cannot reach localhost — expose the port and paste the https URL here
# once you need a verified payment (dart run cli.dart --quick-tunnel).
PUBLIC_BASE_URL=http://localhost:$port

ALLOWED_APP_ORIGIN=${reference['ALLOWED_APP_ORIGIN'] ?? 'http://localhost:3000'}
APP_RETURN_URI_WEB=${reference['APP_RETURN_URI_WEB'] ?? 'https://localhost:3000/'}

ZENPAY_HPP_ENDPOINT_URL=${reference['ZENPAY_HPP_ENDPOINT_URL'] ?? 'https://pay.sandbox.travelpay.com.au/Online/v5'}
ZENPAY_MERCHANT_CODE=${reference['ZENPAY_MERCHANT_CODE'] ?? ''}
ZENPAY_API_KEY=${reference['ZENPAY_API_KEY'] ?? ''}

# Never leaves this process: hashed into the SHA3-512 fingerprint, and used
# again to recompute a callback's ValidationCode.
ZENPAY_USERNAME=${reference['ZENPAY_USERNAME'] ?? ''}
ZENPAY_PASSWORD=${reference['ZENPAY_PASSWORD'] ?? ''}

ZENPAY_ALLOWED_CHECKOUT_HOSTS=${reference['ZENPAY_ALLOWED_CHECKOUT_HOSTS'] ?? 'pay.sandbox.travelpay.com.au'}
CHECKOUT_STATUS_TTL_MINUTES=60

# At least 32 bytes, separate from the ZenPay password: openssl rand -hex 32
TOKEN_SECRET=${reference['TOKEN_SECRET'] ?? ''}
CHECKOUT_TOKEN_TTL_SECONDS=300
''';

/// A `CLAUDE.md` skeleton satisfying `scripts/claude_md_template.md`'s
/// required sections. Per-file coverage entries are the author's to add.
String _claudeMdStub(String packageName, String summary) =>
    '''
# $packageName

$summary Generated by the `zenpay-demo-app` skill — a demonstration of the ZenPay
Hosted Checkout SDKs, not a library.

## Source Guide

<!-- Every file matching lib/**/*.dart and bin/**/*.dart needs a dedicated
     entry here — a heading or a bullet naming its path — or
     `dart run scripts/check_claude_md.dart` fails. Prose mentions do not count. -->

## Related Guides

- **[Monorepo Root](../../CLAUDE.md)** — Melos workspace overview.
- **[Combined Example](../CLAUDE.md)** — the reference integration this demo is modelled on.

## Verification

Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```
''';
