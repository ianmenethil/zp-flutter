/// Checks a generated ZenPay demo against the integration invariants that the
/// compiler and the test suite both miss.
///
/// Every check reads the live repo rather than restating it, so this fails
/// when the repo moves instead of quietly going stale. Run from the
/// repository root:
///
/// ```bash
/// dart run .claude/skills/zenpay-demo-app/scripts/verify_demo_app.dart coffee_shop
/// ```
///
/// A green run means the integration is *wired*. It cannot prove a payment
/// succeeds — that needs sandbox credentials and a public callback URL.
library;

import 'dart:io';

/// One check's outcome.
typedef Check = ({String name, bool passed, String detail});

/// Builds a passing [Check].
Check _pass(String name, String detail) => (name: name, passed: true, detail: detail);

/// Builds a failing [Check].
Check _fail(String name, String detail) => (name: name, passed: false, detail: detail);

/// Every `.dart` file under [dir]'s `lib/` and `bin/`.
List<File> dartSources(String dir) {
  final files = <File>[];
  for (final sub in ['lib', 'bin']) {
    final root = Directory('$dir/$sub');
    if (!root.existsSync()) continue;
    files.addAll(root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')));
  }
  return files;
}

/// The first `file:line` in [files] whose content matches [pattern], or null.
String? locate(List<File> files, Pattern pattern) {
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(pattern)) return '${file.path}:${i + 1}';
    }
  }
  return null;
}

/// Whether an `await` precedes `reserveLaunch()` inside its own function body.
///
/// Scans back from the `reserveLaunch(` line to the nearest line that opens an
/// async function, and reports any `await` in between — that gap is the
/// unbroken user gesture a browser requires to allow `window.open`.
///
/// ponytail: line-scan heuristic, not an AST walk. It catches the real
/// failure (a backend call awaited before reserving) and cannot see an await
/// hidden behind a helper call. Swap in `package:analyzer` if that matters.
Check checkReserveOrdering(List<File> files) {
  const name = 'reserveLaunch() precedes the first await';
  for (final file in files) {
    final lines = file.readAsLinesSync();
    final index = lines.indexWhere((line) => line.contains('reserveLaunch('));
    if (index == -1) continue;

    for (var i = index - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.contains('async {') || line.contains('async{')) {
        return _pass(name, '${file.path}:${index + 1}');
      }
      if (line.contains('await ')) {
        return _fail(name, '${file.path}:${i + 1} awaits before ${file.path}:${index + 1} — the web popup will be blocked');
      }
    }
    return _pass(name, '${file.path}:${index + 1} (no enclosing async function found; ordering unverified)');
  }
  return _fail(name, 'no reserveLaunch() call found — required even on mobile, where it is a no-op');
}

/// Runs every check for the demo named [name] under [root].
List<Check> runChecks(String root, String name) {
  final checks = <Check>[];
  final appDir = '$root/example/${name}_app';
  final backendDir = '$root/example/${name}_backend';
  final hasBackend = Directory(backendDir).existsSync();

  if (!Directory(appDir).existsSync()) {
    return [_fail('demo exists', 'No package at $appDir. Scaffold it with new_demo_app.dart first.')];
  }

  final rootPubspec = File('$root/pubspec.yaml').readAsStringSync();
  for (final member in ['example/${name}_app', if (hasBackend) 'example/${name}_backend']) {
    checks.add(
      rootPubspec.contains('- $member')
          ? _pass('workspace member: $member', 'pubspec.yaml')
          : _fail('workspace member: $member', 'missing from the root pubspec.yaml `workspace:` list — pub cannot resolve it'),
    );
  }

  for (final dir in [appDir, if (hasBackend) backendDir]) {
    final text = File('$dir/pubspec.yaml').readAsStringSync();
    checks
      ..add(
        text.contains('resolution: workspace')
            ? _pass('resolution: workspace in ${dir.split('/').last}', '$dir/pubspec.yaml')
            : _fail('resolution: workspace in ${dir.split('/').last}', 'absent — required of every workspace member'),
      )
      ..add(
        RegExp(r'zenpay_\w+:\s*\n\s+path:').hasMatch(text)
            ? _fail('no path: dep in ${dir.split('/').last}', 'a path: dependency is rejected once a package is a workspace member')
            : _pass('no path: dep in ${dir.split('/').last}', '$dir/pubspec.yaml'),
      );
  }

  final appSources = dartSources(appDir);
  final serverSdkInApp = locate(appSources, 'package:zenpay_dart');
  checks
    ..add(
      serverSdkInApp == null
          ? _pass('zenpay_dart absent from client', 'no server SDK import in the app package')
          : _fail('zenpay_dart absent from client', '$serverSdkInApp — this ships the merchant password to every device'),
    )
    ..add(checkReserveOrdering(appSources));

  final release = locate(appSources, 'releaseLaunchReservation(');
  checks.add(
    release == null
        ? _fail('releaseLaunchReservation() on the failure path', 'absent — a failed backend call leaves a blank tab open')
        : _pass('releaseLaunchReservation() on the failure path', release),
  );

  final returnCase = locate(appSources, 'ZpReturnReceived');
  final statusLookup = locate(appSources, '/api/v1/sessions');
  checks.add(
    returnCase != null && statusLookup == null
        ? _fail('return confirmed against the backend', '$returnCase handles a return but nothing queries /api/v1/sessions — a return is not a payment')
        : _pass('return confirmed against the backend', statusLookup ?? 'no return handling found yet'),
  );

  final popupRelay = locate(appSources, 'completeWebCheckoutReturnIfPopup');
  checks.add(
    popupRelay == null
        ? _fail('web return relay in main()', 'absent — the web build will never receive a return from the checkout tab')
        : _pass('web return relay in main()', popupRelay),
  );

  if (hasBackend) {
    final backendSources = dartSources(backendDir);
    for (final symbol in ['createZpFingerprint', 'createZpCheckoutUrl', 'verifyZpCallback']) {
      final found = locate(backendSources, symbol);
      checks.add(
        found == null ? _fail('backend calls $symbol', 'absent — the demo does not actually exercise zenpay_dart') : _pass('backend calls $symbol', found),
      );
    }
  }

  return checks;
}

/// Entrypoint. Prints one line per check and exits 1 if any failed.
void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.first == '-h' || arguments.first == '--help') {
    stdout.writeln('Usage: dart run .claude/skills/zenpay-demo-app/scripts/verify_demo_app.dart <name> [--root <path>]');
    return;
  }

  final name = arguments.first;
  final rootIndex = arguments.indexOf('--root');
  final root = rootIndex == -1 || rootIndex + 1 >= arguments.length ? Directory.current.path : arguments[rootIndex + 1];

  final checks = runChecks(root, name);
  for (final check in checks) {
    stdout.writeln('${check.passed ? 'PASS' : 'FAIL'}  ${check.name}\n      ${check.detail}');
  }

  final failed = checks.where((c) => !c.passed).length;
  stdout.writeln('\n${checks.length - failed}/${checks.length} passed.');
  if (failed > 0) {
    stdout.writeln('Wiring is incomplete. Fix the FAILs above before reporting the demo done.');
    exit(1);
  }
  stdout.writeln('Wiring verified. This does NOT prove a payment succeeds — that needs sandbox credentials and a public callback URL.');
}
