/// Example merchant HTTP backend for ZenPay Hosted Checkout.
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:zenpay_example_backend/src/attempt_store.dart';
import 'package:zenpay_example_backend/src/config.dart';
import 'package:zenpay_example_backend/src/server_app.dart';

/// ANSI color code for a log [level] — red for errors, yellow for warnings,
/// cyan for info, gray for anything finer.
String _levelColor(Level level) => switch (level) {
  Level.SEVERE || Level.SHOUT => '\x1B[31m',
  Level.WARNING => '\x1B[33m',
  Level.INFO => '\x1B[36m',
  _ => '\x1B[90m',
};

Future<void> main() async {
  // Every request logs one merged record (see buildHandler): full headers
  // and body, plus any business annotations that fired along the way.
  // Level.INFO for a normal 2xx/3xx response, Level.WARNING for 4xx/5xx —
  // set Level.WARNING here to see only the latter.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final sink = record.level >= Level.WARNING ? stderr : stdout;
    final time = record.time.toIso8601String().substring(11, 19);
    final prefix = '[$time] ${record.level.name.padRight(7)} ${record.loggerName}:';
    // Always colored, not gated on stdout.supportsAnsiEscapes: `dart run
    // cli.dart --server` launches this process with piped (not inherited)
    // stdio, so that check sees a pipe and reports false even though the
    // real terminal on the other end of cli.dart's relay supports color
    // fine. Running this file directly also renders correctly either way.
    sink.writeln('${_levelColor(record.level)}$prefix\x1B[0m ${record.message}');
    if (record.error != null) sink.writeln(record.error);
    if (record.stackTrace != null) sink.writeln(record.stackTrace);
  });

  final config = loadConfig();

  // Refuse to start rather than serve a backend that 503s every session and
  // silently rejects every callback. Reporting readiness only on /health means
  // the failure surfaces later, in the app, as an error about the backend.
  final missing = {...sessionConfigurationErrors(config), ...callbackConfigurationErrors(config)};
  if (missing.isNotEmpty) {
    stderr.writeln('Refusing to start — .env is missing required values:');
    for (final key in missing) {
      stderr.writeln('  $key');
    }
    stderr.writeln('See example/backend/.env.example.');
    exit(1);
  }

  // reCAPTCHA is optional (all three vars empty is fine) but never partial:
  // one or two set would leave the client widget rendering while the server
  // silently never enforces it — see recaptchaConfigurationErrors' doc.
  final recaptchaMissing = recaptchaConfigurationErrors(config);
  if (recaptchaMissing.isNotEmpty) {
    stderr.writeln('Refusing to start — reCAPTCHA is partially configured. Set all three, or leave all three empty to disable it:');
    for (final key in recaptchaMissing) {
      stderr.writeln('  $key');
    }
    stderr.writeln('See example/backend/.env.example.');
    exit(1);
  }

  final store = AttemptStore();

  Timer.periodic(const Duration(minutes: 1), (_) {
    store.purgeCreatedBefore(DateTime.now().toUtc().subtract(Duration(minutes: config.checkoutStatusTtlMinutes)));
  });

  final handler = buildHandler(config, store);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port, poweredByHeader: null);

  logEvent(
    'server_started',
    fields: {
      'port': server.port,
      'sessionReady': sessionConfigurationErrors(config).isEmpty,
      'callbackReady': callbackConfigurationErrors(config).isEmpty,
      'routes': [for (final route in describeRoutes()) '${route.method} ${route.path}'],
    },
  );

  // Without this, Ctrl-C leaves the listening socket (and the Timer.periodic
  // above) keeping the isolate alive, which is what makes the terminal that
  // launched this process hang on exit.
  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
  exit(0);
}
