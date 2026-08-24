// Single cross-platform dev launcher, replacing run-*.ps1 (and the .sh
// duplicates those would otherwise need on Linux/macOS).
//
// Usage: dart run <this-file> --bootstrap | --server | --android | --android-webview | --ios | --web | --stream
// (run with --help for the full option list). Findable at any depth in the
// repo — see _repoRoot below — so it's safe to move/rename.
//
// Every mode's final step inherits stdio and blocks for the process's whole
// lifetime (Ctrl+C stops it) — same as running `flutter run` directly: logs
// stream live, nothing runs detached in the background.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

/// This file's own name, as invoked — used in printed usage/next-step text
/// so it stays correct if the file gets renamed or moved.
String get _scriptName => Platform.script.pathSegments.last;

// Colour is opt-out, not opt-in: disabled automatically when stdout isn't a
// real ANSI-capable terminal (piped output, older `cmd.exe`), so redirecting
// `> log.txt` never ends up with raw escape codes in the file.
final bool _color = stdout.supportsAnsiEscapes;
String _ansi(String code, String text) => _color ? '\x1B[${code}m$text\x1B[0m' : text;
String _bold(String s) => _ansi('1', s);
String _cyan(String s) => _ansi('36', s);
String _green(String s) => _ansi('32', s);
String _yellow(String s) => _ansi('33', s);
String _red(String s) => _ansi('31', s);
String _dim(String s) => _ansi('2', s);

void _info(String s) => stdout.writeln(_cyan(s));
void _success(String s) => stdout.writeln(_green(s));
void _warn(String s) => stdout.writeln(_yellow(s));
void _error(String s) => stderr.writeln(_red(s));

String _usage() {
  // Padding is computed from the plain (unstyled) length — colour codes are
  // invisible bytes that would otherwise throw padRight's own count off and
  // misalign every row.
  String row(String left, String right) => '  ${_cyan(left)}${' ' * (26 - left.length).clamp(0, 26)}$right';

  return [
    '${_bold('ZenPay SDK dev launcher')} — runs one mode as a live, attached process',
    '(Ctrl+C stops it; logs stream to this terminal, nothing runs in the',
    'background).',
    '',
    '${_bold('Usage:')} dart run $_scriptName <mode> [options]',
    '',
    _bold('Modes (pick exactly one):'),
    row('--bootstrap', 'First-run setup on a fresh clone.'),
    row('--server', 'Run example/backend.'),
    row('--android', 'Run example/app on Android.'),
    row('--android-webview', 'Run the zenpay_embedded WebView checkout demo on Android.'),
    row('--ios', 'Run example/app on iOS (macOS only).'),
    row('--web', 'Run example/app on Chrome.'),
    row('--stream', 'Mirror an Android device via scrcpy.'),
    row('--tunnel', 'Run the named cloudflared tunnel (saved token).'),
    row('--quick-tunnel', 'Run an ephemeral *.trycloudflare.com tunnel.'),
    row(
      '--docker-build',
      'Build backend + frontend images (docker/local/docker-compose.yml).',
    ),
    row(
      '--docker-run',
      'Run both via Compose (:7000/:8080) + tunnel if .env has a token.',
    ),
    row('--docker-rebuild', 'Stop, remove images, rebuild fresh, and run.'),
    row('--cf-deploy', 'Deploy the Cloudflare Workers backend and Containers.'),
    row(
      '--release:dart:minor',
      'Bump zenpay_dart to the next minor version, prep for pub.dev.',
    ),
    row(
      '--release:dart:major',
      'Bump zenpay_dart to the next major version, prep for pub.dev.',
    ),
    row(
      '--release:flutter:minor',
      'Bump zenpay_flutter to the next minor version, prep for pub.dev.',
    ),
    row(
      '--release:flutter:major',
      'Bump zenpay_flutter to the next major version, prep for pub.dev.',
    ),
    '',
    _bold('Options:'),
    row('--device=<id>', 'Device id for --android / --ios / --stream.'),
    row(
      '--public-base-url=<url>',
      'Value for PUBLIC_BASE_URL (--server). Prompts if omitted.',
    ),
    row('--keep-url', 'Skip the PUBLIC_BASE_URL prompt/update (--server).'),
    row('--skip-certs', 'Skip the local TLS cert step (--bootstrap).'),
    row(
      '--url=<url>',
      'Local URL to expose (--quick-tunnel). Defaults to '
          'PORT from .env, else :7000.',
    ),
    row('-h, --help', 'Show this usage.'),
    '',
    _bold('Examples:'),
    _dim('  dart run $_scriptName --bootstrap'),
    _dim('  dart run $_scriptName --server'),
    _dim(
      '  dart run $_scriptName --server --public-base-url=https://abc.trycloudflare.com',
    ),
    _dim('  dart run $_scriptName --android --device=emulator-5554'),
    _dim('  dart run $_scriptName --android-webview'),
    _dim('  dart run $_scriptName --web'),
    _dim('  dart run $_scriptName --stream'),
    _dim('  dart run $_scriptName --tunnel'),
    _dim('  dart run $_scriptName --quick-tunnel'),
    _dim('  dart run $_scriptName --docker-build'),
    _dim('  dart run $_scriptName --docker-run'),
    _dim('  dart run $_scriptName --docker-rebuild'),
    _dim('  dart run $_scriptName --release:dart:minor'),
    _dim('  dart run $_scriptName --release:flutter:major'),
  ].join('\n');
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('bootstrap', negatable: false, help: 'First-run setup.')
    ..addFlag('server', negatable: false, help: 'Run example/backend.')
    ..addFlag('android', negatable: false, help: 'Run example/app on Android.')
    ..addFlag(
      'android-webview',
      negatable: false,
      help: 'Run the zenpay_embedded WebView checkout demo on Android.',
    )
    ..addFlag(
      'ios',
      negatable: false,
      help: 'Run example/app on iOS (macOS only).',
    )
    ..addFlag('web', negatable: false, help: 'Run example/app on Chrome.')
    ..addFlag(
      'stream',
      negatable: false,
      help: 'Mirror an Android device via scrcpy.',
    )
    ..addFlag(
      'tunnel',
      negatable: false,
      help: 'Run the named cloudflared tunnel (saved token).',
    )
    ..addFlag(
      'quick-tunnel',
      negatable: false,
      help: 'Run an ephemeral *.trycloudflare.com tunnel.',
    )
    ..addFlag(
      'docker-build',
      negatable: false,
      help: 'Build the combined backend + Flutter Web image (zenpay-backend).',
    )
    ..addFlag(
      'docker-run',
      negatable: false,
      help: 'Run the combined image (API + Flutter Web) on port 7000.',
    )
    ..addFlag(
      'docker-rebuild',
      negatable: false,
      help: 'Delete existing image, build fresh, and run.',
    )
    ..addFlag(
      'cf-deploy',
      negatable: false,
      help: 'Deploy the Cloudflare Workers backend and Containers.',
    )
    ..addFlag(
      'release:dart:minor',
      negatable: false,
      help: 'Bump zenpay_dart to the next minor version, prep for pub.dev.',
    )
    ..addFlag(
      'release:dart:major',
      negatable: false,
      help: 'Bump zenpay_dart to the next major version, prep for pub.dev.',
    )
    ..addFlag(
      'release:flutter:minor',
      negatable: false,
      help: 'Bump zenpay_flutter to the next minor version, prep for pub.dev.',
    )
    ..addFlag(
      'release:flutter:major',
      negatable: false,
      help: 'Bump zenpay_flutter to the next major version, prep for pub.dev.',
    )
    ..addOption('device', help: 'Device id for --android / --ios / --stream.')
    ..addOption(
      'public-base-url',
      help: 'Value for PUBLIC_BASE_URL (--server). Prompts if omitted.',
    )
    ..addOption(
      'url',
      help:
          'Local URL to expose (--quick-tunnel). Defaults to PORT from '
          'example/backend/.env, else :7000.',
    )
    ..addFlag(
      'keep-url',
      negatable: false,
      help: 'Skip the PUBLIC_BASE_URL prompt/update (--server).',
    )
    ..addFlag(
      'skip-certs',
      negatable: false,
      help: 'Skip the local TLS cert step (--bootstrap).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (error) {
    _error(error.message);
    stderr
      ..writeln()
      ..writeln(_usage());
    exit(64);
  }

  if (args['help'] as bool) {
    stdout.writeln(_usage());
    return;
  }

  final modes = <String>[
    if (args['bootstrap'] as bool) 'bootstrap',
    if (args['server'] as bool) 'server',
    if (args['android'] as bool) 'android',
    if (args['android-webview'] as bool) 'android-webview',
    if (args['ios'] as bool) 'ios',
    if (args['web'] as bool) 'web',
    if (args['stream'] as bool) 'stream',
    if (args['tunnel'] as bool) 'tunnel',
    if (args['quick-tunnel'] as bool) 'quick-tunnel',
    if (args['docker-build'] as bool) 'docker-build',
    if (args['docker-run'] as bool) 'docker-run',
    if (args['docker-rebuild'] as bool) 'docker-rebuild',
    if (args['cf-deploy'] as bool) 'cf-deploy',
    if (args['release:dart:minor'] as bool) 'release:dart:minor',
    if (args['release:dart:major'] as bool) 'release:dart:major',
    if (args['release:flutter:minor'] as bool) 'release:flutter:minor',
    if (args['release:flutter:major'] as bool) 'release:flutter:major',
  ];
  if (modes.length != 1) {
    _error(
      modes.isEmpty
          ? 'Pick exactly one of --bootstrap --server --android --android-webview '
                '--ios --web --stream --tunnel --quick-tunnel --docker-build '
                '--docker-run --docker-rebuild --release:dart:minor --release:dart:major '
                '--release:flutter:major.'
          : 'Only one mode at a time: got ${modes.join(', ')}.',
    );
    stderr
      ..writeln()
      ..writeln(_usage());
    exit(64);
  }

  final mode = modes.single;

  // --stream doesn't touch the repo at all (just launches scrcpy), so it's
  // the one mode that works from anywhere, not just inside the repo.
  if (mode == 'stream') {
    await _stream(deviceId: args['device'] as String?);
    return;
  }

  final root = _repoRoot();

  if (mode == 'bootstrap') {
    await _bootstrap(root, skipCerts: args['skip-certs'] as bool);
  } else if (mode == 'server') {
    await _server(
      root,
      publicBaseUrl: args['public-base-url'] as String?,
      keepUrl: args['keep-url'] as bool,
    );
  } else if (mode == 'android') {
    await _android(root, deviceId: args['device'] as String?);
  } else if (mode == 'android-webview') {
    await _android(root, deviceId: args['device'] as String?, target: 'lib/embedded_demo_main.dart');
  } else if (mode == 'ios') {
    await _ios(root, deviceId: args['device'] as String?);
  } else if (mode == 'web') {
    await _web(root);
  } else if (mode == 'tunnel') {
    await _tunnel(root);
  } else if (mode == 'quick-tunnel') {
    await _quickTunnel(root, url: args['url'] as String?);
  } else if (mode == 'docker-build') {
    await _dockerBuild(root);
  } else if (mode == 'docker-run') {
    await _dockerRun(root);
  } else if (mode == 'docker-rebuild') {
    await _dockerRebuild(root);
  } else if (mode == 'cf-deploy') {
    await _cfDeploy(root);
  } else if (mode.startsWith('release:')) {
    // release:<dart|flutter>:<minor|major>
    final parts = mode.split(':');
    await _release(
      root,
      package: parts[1] == 'dart' ? 'zenpay_dart' : 'zenpay_flutter',
      bump: parts[2],
    );
  }
}

/// Walks up from this script's own location to find the monorepo root.
/// Deliberately not hardcoded to a fixed depth (e.g. "two folders up") —
/// this file is meant to be runnable from wherever it's placed (repo root,
/// scripts/, anywhere), so resolution has to follow it rather than assume
/// where it lives.
String _repoRoot() {
  var dir = File.fromUri(Platform.script).parent;
  while (true) {
    if (Directory('${dir.path}/example').existsSync() && Directory('${dir.path}/zenpay_flutter').existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      _error(
        'Could not find the zp-flutter-sdk repo root above '
        '${Platform.script.toFilePath()}.',
      );
      exit(1);
    }
    dir = parent;
  }
}

bool _hasCommand(String name) {
  try {
    return Process.runSync(Platform.isWindows ? 'where' : 'which', [
          name,
        ]).exitCode ==
        0;
  } on Object {
    return false;
  }
}

/// Resolves [name] to a full, directly-launchable path on Windows; a no-op
/// everywhere else.
///
/// This is what lets [_runLive] avoid `runInShell: true`. That flag wraps
/// the child in an extra `cmd.exe /c` layer, and on Windows that layer is
/// actively harmful for a long-running interactive process: `cmd.exe`
/// intercepts Ctrl+C with its own "Terminate batch job (Y/N)?" prompt and
/// tears the child down before it gets a chance to restore the console's
/// input mode, which is what leaves the whole terminal typing-broken
/// afterward — see https://github.com/flutter/flutter/issues/157509 and
/// https://github.com/dart-lang/sdk/issues/48439. Passing a resolved full
/// path directly to Process.start sidesteps the extra shell layer entirely;
/// Windows still launches a `.bat`/`.cmd` correctly given its exact path
/// (verified: flutter.bat launches fine via Process.start with no
/// runInShell once given its full path from `where`).
///
/// `where` can list more than one match for a name (e.g. a bare `flutter`
/// POSIX shim alongside `flutter.bat`) — the first entry with a real
/// Windows-executable extension is preferred; Windows can't run the
/// extension-less one directly.
String _resolveExecutable(String name) {
  if (!Platform.isWindows) return name;
  try {
    final result = Process.runSync('where', [name]);
    if (result.exitCode != 0) return name;
    final candidates = const LineSplitter().convert(result.stdout as String).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    for (final candidate in candidates) {
      final ext = candidate.split('.').last.toLowerCase();
      if (const {'exe', 'bat', 'cmd', 'com'}.contains(ext)) return candidate;
    }
    return candidates.isEmpty ? name : candidates.first;
  } on Object {
    return name;
  }
}

/// Streams [executable]'s stdio live and waits for it to exit.
Future<int> _runLive(
  String executable,
  List<String> args, {
  String? cwd,
  bool inheritStdio = true,
  bool runInShell = false,
  Map<String, String>? environment,
}) async {
  StreamSubscription<ProcessSignal>? sigintSub;
  if (inheritStdio) {
    // Ignore SIGINT so we don't drop out of the CLI while the child is still running.
    // The child process receives the signal too (e.g., cmd.exe /c flutter.bat)
    // and should terminate gracefully. If we exit immediately, the terminal gets corrupted.
    try {
      sigintSub = ProcessSignal.sigint.watch().listen((_) {});
    } on Object catch (_) {} // ProcessSignal.sigint might not be supported on all platforms, though it is on Windows.

    // runInShell is opt-in (see _cfDeploy): for a one-shot, non-interactive
    // command it makes this spawn identically to typing it at a shell
    // prompt. It's not the default because cmd.exe's own Ctrl+C handling is
    // what corrupts the terminal for long-lived interactive processes (see
    // _resolveExecutable's doc comment) — a risk that doesn't apply to a
    // command that just runs to completion on its own.
    final process = await Process.start(
      runInShell ? executable : _resolveExecutable(executable),
      args,
      workingDirectory: cwd,
      mode: ProcessStartMode.inheritStdio,
      runInShell: runInShell,
      environment: environment,
    );
    final exitCode = await process.exitCode;
    await sigintSub?.cancel();
    return exitCode;
  } else {
    final process = await Process.start(
      _resolveExecutable(executable),
      args,
      workingDirectory: cwd,
      environment: environment,
    );
    process.stdout.listen(stdout.add);
    process.stderr.listen(stderr.add);

    // We explicitly do not pipe stdin or listen to it, because doing so
    // with certain processes (like dart run) on Windows can permanently
    // break the terminal's input mode upon a Ctrl+C exit.

    return process.exitCode;
  }
}

/// Like [_runLive], but a non-zero exit aborts this script — for setup steps
/// later steps depend on.
Future<void> _runChecked(
  String executable,
  List<String> args, {
  String? cwd,
}) async {
  final code = await _runLive(executable, args, cwd: cwd);
  if (code != 0) {
    exit(code);
  }
}

/// The final step of every mode: runs the long-lived app/server process
/// attached to this script's own stdio, then exits with its code. Never
/// returns — this *is* the "ongoing process you can see the logs of", not a
/// background launch.
Future<Never> _execForeground(
  String executable,
  List<String> args, {
  String? cwd,
  bool inheritStdio = true,
  bool runInShell = false,
  Map<String, String>? environment,
}) async {
  exit(await _runLive(executable, args, cwd: cwd, inheritStdio: inheritStdio, runInShell: runInShell, environment: environment));
}

/// First-run setup for a fresh clone: resolves the pub workspace and creates
/// the local files that are deliberately not committed.
///
/// Does NOT regenerate example/app/android or ios — those are committed and
/// hold hand-edited config (intent-filter, entitlements, signing, bundle ids)
/// regenerating would destroy. Use apply_platform_config.dart for that.
Future<void> _bootstrap(String root, {required bool skipCerts}) async {
  for (final cmd in ['flutter', 'dart']) {
    if (!_hasCommand(cmd)) {
      _error('Missing required command: $cmd');
      exit(1);
    }
  }

  _info('Resolving pub workspace...');
  await _runChecked('dart', ['pub', 'get'], cwd: root);

  for (final pkg in ['example/backend', 'example/app']) {
    final envFile = File('$root/$pkg/.env');
    final template = File('${envFile.path}.example');
    if (template.existsSync() && !envFile.existsSync()) {
      template.copySync(envFile.path);
      _info('Created $pkg/.env from template');
    }
  }

  // The SDK rejects any non-https return URI, so the web flow needs TLS even
  // on localhost. Mobile does not — its return is an App Link on the public
  // host.
  if (!skipCerts) {
    final appDir = '$root/example/app';
    if (File('$appDir/localhost+2.pem').existsSync()) {
      stdout.writeln('TLS cert already present.');
    } else if (_hasCommand('mkcert')) {
      await _runChecked('mkcert', ['-install'], cwd: appDir);
      await _runChecked('mkcert', [
        'localhost',
        '127.0.0.1',
        '::1',
      ], cwd: appDir);
    } else {
      _warn(
        'mkcert not installed — skipping TLS cert. Web checkout returns '
        'will not match until you install it and re-run.',
      );
    }
  }

  stdout.writeln();
  _success('Bootstrap complete. Next:');
  stdout
    ..writeln(
      '  1. Fill in ZENPAY_* credentials in example/backend/.env — the '
      'server will not start without them.',
    )
    ..writeln(
      '  2. dart run $_scriptName --server   '
      '(prompts for PUBLIC_BASE_URL and propagates it)',
    )
    ..writeln('  3. dart run $_scriptName --android | --ios | --web');
}

/// Starts the example backend. Every other mode assumes this is already
/// running.
///
/// Prompts for PUBLIC_BASE_URL first, because it changes every time a tunnel
/// is restarted and a stale value fails in two ways that are hard to spot:
/// ZenPay posts callbacks to the dead URL, and the mobile return URI stops
/// matching.
Future<void> _server(
  String root, {
  required bool keepUrl,
  String? publicBaseUrl,
}) async {
  final backendDir = '$root/example/backend';
  final envFile = File('$backendDir/.env');
  if (!envFile.existsSync()) {
    _error(
      'No .env at ${envFile.path} — copy .env.example to .env and fill '
      'in your ZenPay credentials.',
    );
    exit(1);
  }

  if (!keepUrl) {
    var content = envFile.readAsStringSync();
    final current =
        RegExp(
          r'^PUBLIC_BASE_URL\s*=\s*(.*)$',
          multiLine: true,
        ).firstMatch(content)?.group(1)?.trim() ??
        '(not set)';

    var newUrl = publicBaseUrl;
    if (newUrl == null) {
      _info('Current PUBLIC_BASE_URL: $current');
      stdout
        ..writeln(
          'For live callbacks or mobile deep links this must be a public '
          'HTTPS host:',
        )
        ..writeln('  cloudflared tunnel --url http://localhost:7000')
        ..write('New PUBLIC_BASE_URL (Enter to keep): ');
      newUrl = stdin.readLineSync()?.trim() ?? '';
    }

    // Three other places derive from this host. Leaving any of them stale
    // fails silently — the SDK compares the return URI exactly, and App Link
    // verification compares the host — so update them here rather than
    // printing instructions and hoping.
    if (newUrl.isNotEmpty) {
      content = content.replaceFirst(
        RegExp(r'^PUBLIC_BASE_URL\s*=.*$', multiLine: true),
        'PUBLIC_BASE_URL=$newUrl',
      );
      envFile.writeAsStringSync(content);
      _info('PUBLIC_BASE_URL set to $newUrl');

      final mobileReturn = '${newUrl.replaceFirst(RegExp(r'/+$'), '')}/zenpay/app-return';
      final appEnv = File('$root/example/app/.env');
      if (appEnv.existsSync()) {
        appEnv.writeAsStringSync(
          appEnv.readAsStringSync().replaceFirst(
            RegExp(r'^APP_RETURN_URI_MOBILE\s*=.*$', multiLine: true),
            'APP_RETURN_URI_MOBILE=$mobileReturn',
          ),
        );
        _info('APP_RETURN_URI_MOBILE -> $mobileReturn');
      } else {
        _warn('No example/app/.env — copy .env.example, then re-run.');
      }

      if (Directory('$root/example/app/android').existsSync()) {
        await _runChecked('dart', [
          'run',
          'scripts/apply_platform_config.dart',
          '--host',
          Uri.parse(newUrl).host,
        ], cwd: root);
      }
    }
  }

  await _execForeground(
    'dart',
    ['run', 'bin/server.dart'],
    cwd: backendDir,
    inheritStdio: false,
  );
}

/// Assumes the backend is already running.
///
/// `adb reverse` is what lets the device reach the backend on the host's
/// localhost. It is passed `-s` explicitly because a bare `adb reverse`
/// fails with "more than one device/emulator" whenever one phone is
/// connected by USB and wirelessly at once, which adb reports as two
/// targets for the same device.
Future<void> _android(String root, {String? deviceId, String? target}) async {
  final device = deviceId ?? _pickAdbDevice();

  _info('Using device: $device');
  await _runChecked(_findAdb(), ['-s', device, 'reverse', 'tcp:7000', 'tcp:7000']);

  await _execForeground('flutter', [
    'run',
    '-d',
    device,
    if (target != null) ...['-t', target],
    '--dart-define-from-file=.env',
  ], cwd: '$root/example/app');
}

/// Auto-picks a single connected `adb` device, or the plain USB serial when
/// the same phone shows up twice (USB + wireless), or exits with the reason
/// it couldn't.
String _findAdb() {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null) {
    final sdkAdb = '$localAppData\\Android\\sdk\\platform-tools\\adb.exe';
    if (File(sdkAdb).existsSync()) return sdkAdb;
  }
  return _resolveExecutable('adb');
}

String _pickAdbDevice() {
  final result = Process.runSync(_findAdb(), ['devices']);
  final devices = const LineSplitter()
      .convert(result.stdout as String)
      .map((line) => RegExp(r'^(\S+)\s+device$').firstMatch(line)?.group(1))
      .whereType<String>()
      .toList();

  if (devices.isEmpty) {
    _error('No adb devices found. Connect a device or start an emulator.');
    exit(1);
  }
  if (devices.length == 1) return devices.single;

  // Same phone over USB and wireless shows up twice — prefer the plain USB
  // serial (no "adb-" mDNS prefix).
  final usb = devices.where((d) => !d.startsWith('adb-')).toList();
  if (usb.length == 1) {
    _warn(
      'Multiple adb targets; using USB device ${usb.single} '
      '(pass --device to override).',
    );
    return usb.single;
  }

  stdout.writeln('Multiple devices found:');
  for (final d in devices) {
    stdout.writeln('  $d');
  }
  _error('Ambiguous — re-run with --device <id>.');
  exit(1);
}

/// Requires macOS + Xcode — Flutter cannot build iOS on Windows or Linux at
/// all, not even against a physical device.
///
/// Assumes the backend is already running. There is no adb-reverse
/// equivalent: the simulator shares the host's localhost directly, and a
/// physical device needs the backend on the LAN or behind a tunnel (see
/// example/backend/.env.example, PUBLIC_BASE_URL).
Future<void> _ios(String root, {String? deviceId}) async {
  if (!Platform.isMacOS) {
    _error(
      'iOS requires macOS + Xcode — Flutter cannot build iOS on this '
      'platform at all, not even against a physical device.',
    );
    exit(1);
  }

  await _execForeground('flutter', [
    'run',
    if (deviceId != null) ...['-d', deviceId],
    '--dart-define-from-file=.env',
  ], cwd: '$root/example/app');
}

/// Assumes the backend is already running.
///
/// TLS: the SDK requires an https return URI, so APP_RETURN_URI_WEB points
/// at https://localhost:3000. That only works if Flutter serves over TLS,
/// which needs a local cert. Deliberately not running `mkcert -install`
/// here: that writes a CA into the machine trust store, which is not
/// something a run command should do behind your back. Without the cert
/// this still runs, over plain http, and Chrome shows a warning.
Future<void> _web(String root) async {
  final appDir = '$root/example/app';
  final cert = File('$appDir/localhost+2.pem');
  final key = File('$appDir/localhost+2-key.pem');

  if (!(cert.existsSync() && key.existsSync()) && _hasCommand('mkcert')) {
    _info('No TLS cert — running mkcert in example/app.');
    final code = await _runLive('mkcert', [
      'localhost',
      '127.0.0.1',
      '::1',
    ], cwd: appDir);
    if (code != 0) {
      _warn('mkcert failed (exit $code) — continuing without cert.');
    }
  }

  final hasTls = cert.existsSync() && key.existsSync();
  if (!hasTls) {
    _warn(
      'No TLS cert — serving http. The https return URI will not match. '
      'Install mkcert (choco install mkcert), run "mkcert -install" once, '
      'then re-run this command.',
    );
  }

  await _execForeground('flutter', [
    'run',
    '-d',
    'chrome',
    '--web-hostname',
    'localhost',
    '--web-port',
    '3000',
    // Do not add --web-browser-flag=--window-size=W,H here. flutter
    // registers --web-browser-flag as an addMultiOption and package:args
    // splits its value on every comma (parser.dart:342, no escape), so the
    // height arrives as a separate argument that Chrome resolves as a
    // 32-bit IP and opens in a junk tab. For a phone viewport use Chrome's
    // device toolbar: F12, Ctrl+Shift+M.
    '--web-browser-flag=--auto-open-devtools-for-tabs',
    if (hasTls) ...[
      '--web-tls-cert-path',
      'localhost+2.pem',
      '--web-tls-cert-key-path',
      'localhost+2-key.pem',
    ],
    '--dart-define-from-file=.env',
  ], cwd: appDir);
}

/// Mirrors a connected Android device's screen via `scrcpy` — independent of
/// every other mode; useful on its own (watching the phone while driving
/// `--android` from another terminal) so it doesn't require the repo at all.
Future<void> _stream({String? deviceId}) async {
  if (!_hasCommand('scrcpy')) {
    _error(
      'scrcpy not found on PATH. Get it from '
      'https://github.com/Genymobile/scrcpy/releases and re-run.',
    );
    exit(1);
  }

  // Use the Android SDK's adb if available, to prevent adb daemon version conflicts
  // with scrcpy's bundled adb when using Flutter/Android Studio simultaneously.
  final sdkAdb = _findAdb();

  final device = deviceId ?? _pickAdbDevice();
  await _execForeground(
    'scrcpy',
    ['-s', device, '--no-clipboard-autosync', '--no-audio'],
    environment: sdkAdb != 'adb' ? {'ADB': sdkAdb} : null,
  );
}

const _cloudflaredInstallHint =
    'cloudflared not found on PATH. Get it from '
    'https://github.com/cloudflare/cloudflared/releases and re-run.';

/// Runs the named tunnel already set up in the Cloudflare dashboard —
/// `cloudflared tunnel run --token <token>`. The token is a durable
/// credential (unlike --quick-tunnel's throwaway URL), so it's persisted in
/// `example/backend/.env` as `CLOUDFLARE_TUNNEL_TOKEN`, same
/// check-display-prompt-save flow as `--server`'s PUBLIC_BASE_URL: shows the
/// current value, Enter keeps it, anything else replaces and saves it.
Future<void> _tunnel(String root) async {
  if (!_hasCommand('cloudflared')) {
    _error(_cloudflaredInstallHint);
    exit(1);
  }

  final envFile = File('$root/example/backend/.env');
  if (!envFile.existsSync()) {
    _error('No .env at ${envFile.path} — copy .env.example to .env first.');
    exit(1);
  }

  var content = envFile.readAsStringSync();
  final tokenPattern = RegExp(
    r'^CLOUDFLARE_TUNNEL_TOKEN\s*=\s*(.*)$',
    multiLine: true,
  );
  final current = tokenPattern.firstMatch(content)?.group(1)?.trim() ?? '';

  if (current.isNotEmpty) {
    _info('Current CLOUDFLARE_TUNNEL_TOKEN: ${_maskSecret(current)}');
    stdout.write('Enter to keep, or paste a new token: ');
  } else {
    stdout.write(
      'No CLOUDFLARE_TUNNEL_TOKEN set — paste your cloudflared tunnel '
      'token (Cloudflare Zero Trust > Networks > Tunnels): ',
    );
  }
  final newToken = stdin.readLineSync()?.trim() ?? '';
  final token = newToken.isEmpty ? current : newToken;

  if (token.isEmpty) {
    _error('A token is required for --tunnel.');
    exit(1);
  }

  if (newToken.isNotEmpty && newToken != current) {
    content = tokenPattern.hasMatch(content)
        ? content.replaceFirst(
            tokenPattern,
            'CLOUDFLARE_TUNNEL_TOKEN=$newToken',
          )
        : '${content.trimRight()}\nCLOUDFLARE_TUNNEL_TOKEN=$newToken\n';
    envFile.writeAsStringSync(content);
    _info('CLOUDFLARE_TUNNEL_TOKEN saved.');
  }

  // cloudflared logs its own "Environmental variables" diagnostic line on
  // startup, dumping any inherited *TUNNEL_* env var verbatim — it only
  // masks the exact name it registers for --token (TUNNEL_TOKEN), not this
  // machine's differently-named CF_TUNNEL_TOKEN user env var, so it would
  // otherwise print the raw token. Blanking it for this child process only
  // (not the persistent Windows variable) closes that without touching
  // anything outside this one invocation — the token still reaches
  // cloudflared correctly via the explicit --token argument above.
  await _execForeground(
    'cloudflared',
    ['tunnel', 'run', '--token', token],
    environment: {'CF_TUNNEL_TOKEN': ''},
  );
}

/// Masks a secret the same partial way as `example/backend`'s
/// `_maskSecret`: first/last 3 characters kept, rest replaced with `...`.
String _maskSecret(String value) => value.length <= 6 ? '...' : '${value.substring(0, 3)}...${value.substring(value.length - 3)}';

/// Runs an ephemeral quick tunnel — `cloudflared tunnel --url <url>` — that
/// needs no Cloudflare account setup, prints a random
/// `https://*.trycloudflare.com` URL, and dies with the process. That
/// printed URL is what you then paste into
/// `dart run $_scriptName --server --public-base-url=<url>`.
Future<void> _quickTunnel(String root, {String? url}) async {
  if (!_hasCommand('cloudflared')) {
    _error(_cloudflaredInstallHint);
    exit(1);
  }

  final target = url ?? _defaultQuickTunnelUrl(root);
  _info(
    'Tunneling $target — copy the printed https://*.trycloudflare.com URL '
    'into `dart run $_scriptName --server --public-base-url=<url>`.',
  );
  await _execForeground('cloudflared', ['tunnel', '--url', target]);
}

/// `http://localhost:<PORT>`, reading PORT from example/backend/.env (same
/// default the backend itself uses) so this needs no separate config of its
/// own; falls back to :7000 — the backend's own hardcoded default — if
/// there's no .env yet.
String _defaultQuickTunnelUrl(String root) {
  final envFile = File('$root/example/backend/.env');
  if (envFile.existsSync()) {
    final port = RegExp(
      r'^PORT\s*=\s*(.*)$',
      multiLine: true,
    ).firstMatch(envFile.readAsStringSync())?.group(1)?.trim();
    if (port != null && port.isNotEmpty) return 'http://localhost:$port';
  }
  return 'http://localhost:7000';
}

/// Bumps [package]'s version and preps it for a pub.dev publish, via Melos.
///
/// [bump] is `'minor'` or `'major'`. The target is always a stable exact
/// version with any `-dev.N` prerelease dropped (e.g. `0.1.0-dev.1` -> minor
/// `0.2.0`, major `1.0.0`) — passed to `melos version` as an exact version,
/// not the `minor`/`major` keyword. Melos's own keyword bump only reads the
/// release type when the current version is *not* already a same-preid
/// prerelease; on a `-dev.N` version with no `--graduate` (which cannot be
/// combined with a manual version anyway) it ignores major/minor/patch
/// entirely and just increments the prerelease counter instead. Passing the
/// exact computed version sidesteps that and always sets precisely what was
/// asked for.
///
/// Deliberately stops short of anything consequential: `melos version` runs
/// with `--no-git-tag-version --no-git-commit-version` (committing is yours
/// to do, not this script's), and the actual `dart pub publish` is never run
/// here — only validated with `--dry-run`. A pub.dev publish cannot be
/// undone, so the real publish is always a separate, manual, deliberate step.
Future<void> _release(
  String root, {
  required String package,
  required String bump,
}) async {
  final pubspecFile = File('$root/$package/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    _error('No pubspec.yaml at ${pubspecFile.path}.');
    exit(1);
  }

  final current = RegExp(
    r'^version:\s*(\S+)$',
    multiLine: true,
  ).firstMatch(pubspecFile.readAsStringSync())?.group(1);
  if (current == null) {
    _error('No "version:" line found in ${pubspecFile.path}.');
    exit(1);
  }

  // Drop any -dev.N (or other) prerelease/build suffix before computing the
  // bump — the target is always a plain stable major.minor.patch.
  final core = current.split(RegExp('[+-]')).first;
  final parts = core.split('.').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) {
    _error('Cannot parse version "$current" in ${pubspecFile.path}.');
    exit(1);
  }
  final major = parts[0]!;
  final minor = parts[1]!;
  final target = bump == 'major' ? '${major + 1}.0.0' : '$major.${minor + 1}.0';

  _info('$package: $current -> $target');
  await _runChecked('dart', [
    'run',
    'melos',
    'version',
    package,
    target,
    '--no-git-tag-version',
    '--no-git-commit-version',
  ], cwd: root);

  _info('Validating with dart pub publish --dry-run...');
  await _runChecked('dart', [
    'pub',
    'publish',
    '--dry-run',
  ], cwd: '$root/$package');

  stdout.writeln();
  _success('$package is at $target and ready to publish.');
  stdout
    ..writeln(
      'Nothing was committed, tagged, or published — that is all left to you:',
    )
    ..writeln(
      '  1. Review the diff (pubspec.yaml, CHANGELOG.md), commit it.',
    )
    ..writeln('  2. cd $package && dart pub publish');
}

/// Path to the Compose file, relative to the repo root — every `docker
/// compose` invocation below passes this via `-f` rather than `cd`-ing into
/// `docker/`,
/// so `context: ..`/`env_file: ../example/backend/.env` inside it keep
/// resolving relative to the compose file's own location, not the shell cwd.
const _composeFile = 'docker/local/docker-compose.yml';

const _dockerBackendPort = 7000;
const _dockerFrontendPort = 8080;

/// Verifies `docker compose` is installed (the v2 plugin subcommand, not the
/// standalone `docker-compose` v1 binary) and Docker Desktop is available.
Future<void> _requireDockerCompose() async {
  if (!_hasCommand('docker')) {
    _error('docker command not found. Please install Docker Desktop.');
    exit(1);
  }
  final result = await Process.run('docker', ['compose', 'version']);
  if (result.exitCode != 0) {
    _error(
      '`docker compose` is not available (Docker Compose v2 plugin). '
      'Update Docker Desktop, or install the compose plugin separately.',
    );
    exit(1);
  }
}

/// Backend container needs `example/backend/service-account.json` to exist
/// unconditionally — `docker/local/docker-compose.yml` bind-mounts it by a fixed
/// path, so a missing file fails the whole `docker compose up`, not just
/// App Check enforcement (unlike the old single-image flow, which only
/// mounted it when `.env` pointed at one).
void _requireServiceAccountFile(String root) {
  final envFile = File('$root/example/backend/.env');
  if (!envFile.existsSync()) {
    _error(
      'No example/backend/.env — copy .env.example and fill in your ZenPay '
      'credentials before running Docker.',
    );
    exit(1);
  }
  final serviceAccountFile = File('$root/example/backend/service-account.json');
  if (!serviceAccountFile.existsSync()) {
    _error(
      'docker/local/docker-compose.yml bind-mounts example/backend/service-account.json '
      'into the backend container — that file does not exist, so `docker compose up` '
      'will fail. Place your Firebase service account key there, or remove the '
      '`volumes:` line for the backend service in docker/local/docker-compose.yml if you '
      "don't need App Check enforcement.",
    );
    exit(1);
  }
}

/// Docker's frontend (`docker/local/Dockerfile.frontend`) terminates TLS with the
/// same mkcert cert [_web] uses, since the SDK requires an https return URI
/// (see [_web]'s doc comment). Unlike [_web], this hard-blocks instead of
/// falling back to plain http: a container failing deep inside its own logs
/// is much harder to diagnose than failing here, before anything builds.
/// Deliberately not running `mkcert -install` here either — same reasoning
/// as [_web].
Future<void> _requireDockerTlsCert(String root) async {
  final appDir = '$root/example/app';
  final cert = File('$appDir/localhost+2.pem');
  final key = File('$appDir/localhost+2-key.pem');

  if (!(cert.existsSync() && key.existsSync()) && _hasCommand('mkcert')) {
    _info('No TLS cert — running mkcert in example/app.');
    final code = await _runLive('mkcert', [
      'localhost',
      '127.0.0.1',
      '::1',
    ], cwd: appDir);
    if (code != 0) {
      _error('mkcert failed (exit $code).');
      exit(1);
    }
  }

  if (!(cert.existsSync() && key.existsSync())) {
    _error(
      "Docker's frontend requires https (docker/local/Dockerfile.frontend "
      'terminates TLS with this cert) and no TLS cert was found. Install '
      'mkcert (choco install mkcert), run "mkcert -install" once, then '
      're-run this command.',
    );
    exit(1);
  }
}

Future<void> _dockerBuild(String root) async {
  await _requireDockerCompose();

  _info('Building backend + frontend Docker images (docker compose)...');
  await _runChecked('docker', [
    'compose',
    '-f',
    _composeFile,
    'build',
  ], cwd: root);
  _success('Docker images built successfully.');
}

/// True if [port] can be bound on localhost right now. Checked before `-p`
/// publishing it, since Docker's own "port is already allocated" failure
/// only happens for other Docker containers — a native process (e.g. a
/// `--server` dev instance) holding the port instead lets `docker run`
/// succeed with a container that starts fine but can never be reached, which
/// looks identical to a broken image from the outside.
Future<bool> _isPortFree(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    await socket.close();
    return true;
  } on Object {
    return false;
  }
}

/// Reads `CLOUDFLARE_TUNNEL_TOKEN` from example/backend/.env without
/// prompting — unlike [_tunnel], which is interactive by design. Empty/
/// absent is not an error here: `--docker-run` must still work standalone
/// for anyone not routing live ZenPay callbacks through it.
String _readTunnelToken(String root) {
  final envFile = File('$root/example/backend/.env');
  if (!envFile.existsSync()) return '';
  return RegExp(
        r'^CLOUDFLARE_TUNNEL_TOKEN\s*=\s*(.*)$',
        multiLine: true,
      ).firstMatch(envFile.readAsStringSync())?.group(1)?.trim() ??
      '';
}

Future<void> _dockerRun(String root) async {
  await _requireDockerCompose();
  _requireServiceAccountFile(root);
  await _requireDockerTlsCert(root);

  for (final port in [_dockerBackendPort, _dockerFrontendPort]) {
    if (!await _isPortFree(port)) {
      _error(
        'Port $port is already in use — the container would start but '
        'never be reachable. Stop whatever is bound to it (a native '
        '`--server` dev instance, or another container) and re-run. Find it '
        'with: ${Platform.isWindows ? 'netstat -ano | findstr :$port' : 'lsof -i:$port'}',
      );
      exit(1);
    }
  }

  // Tunnel runs natively (not in Compose) pointed at localhost:$_dockerBackendPort
  // — the same target that already works via Docker's -p publishing — so no
  // Cloudflare-side ingress reconfiguration is needed. Started before Compose
  // and killed after it exits so nothing outlives this command (see file-level
  // "nothing runs detached in the background" note at the top of this file).
  Process? tunnelProcess;
  final tunnelToken = _readTunnelToken(root);
  if (tunnelToken.isNotEmpty) {
    if (!_hasCommand('cloudflared')) {
      _error(_cloudflaredInstallHint);
      exit(1);
    }
    _info('Starting cloudflared tunnel (CLOUDFLARE_TUNNEL_TOKEN from .env)...');
    // See _tunnel's comment: blanks this machine's CF_TUNNEL_TOKEN user env
    // var for this child only, so cloudflared's own unmasked env-var log
    // line doesn't leak it (the --token argument above is unaffected).
    tunnelProcess = await Process.start(
      'cloudflared',
      [
        'tunnel',
        'run',
        '--token',
        tunnelToken,
      ],
      environment: {'CF_TUNNEL_TOKEN': ''},
    );
    tunnelProcess.stdout.listen(stdout.add);
    tunnelProcess.stderr.listen(stderr.add);
  } else {
    _info('No CLOUDFLARE_TUNNEL_TOKEN in .env — skipping tunnel, backend/frontend only.');
  }

  _info(
    'Running Docker Compose (zenpay-backend on http://localhost:$_dockerBackendPort, '
    'zenpay-frontend on http://localhost:$_dockerFrontendPort)...',
  );
  final exitCode = await _runLive('docker', [
    'compose',
    '-f',
    _composeFile,
    'up',
  ], cwd: root);
  tunnelProcess?.kill();
  exit(exitCode);
}

Future<void> _dockerRebuild(String root) async {
  await _requireDockerCompose();

  _info('Stopping containers and removing existing images (docker compose down)...');
  // Ignore failure if nothing is running yet.
  await Process.run('docker', [
    'compose',
    '-f',
    _composeFile,
    'down',
    '--rmi',
    'local',
  ], workingDirectory: root);

  await _dockerBuild(root);
  await _dockerRun(root);
}

Future<void> _cfDeploy(String root) async {
  _info('Deploying Cloudflare Workers and Containers (via npm run cf:deploy)...');

  if (!File('$root/package.json').existsSync()) {
    _error('package.json not found in the root directory.');
    exit(1);
  }

  // Windows needs npm.cmd instead of just npm
  final npmCommand = Platform.isWindows ? 'npm.cmd' : 'npm';

  // runInShell so this spawns exactly as if you'd typed `npm run cf:deploy`
  // yourself — wrangler deploy is a one-shot command that runs to
  // completion on its own, not a long-lived process a user interrupts with
  // Ctrl+C, so runInShell's terminal-corruption risk (see _runLive) doesn't
  // apply here.
  await _execForeground(npmCommand, ['run', 'cf:deploy'], cwd: root, runInShell: true);
}
