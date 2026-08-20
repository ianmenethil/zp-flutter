/// Example merchant HTTP backend for ZenPay Hosted Checkout.
library;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:zenpay_example_backend/src/attempt_store.dart';
import 'package:zenpay_example_backend/src/config.dart';
import 'package:zenpay_example_backend/src/server_app.dart';

Future<void> main() async {
  // Every request logs one merged record (see buildHandler): full headers
  // and body, plus any business annotations that fired along the way.
  // Level.INFO for a normal 2xx/3xx response, Level.WARNING for 4xx/5xx —
  // set Level.WARNING here to see only the latter.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    (record.level >= Level.WARNING ? stderr : stdout).writeln(record.message);
  });

  final config = loadConfig();

  // Refuse to start rather than serve a backend that 503s every session and
  // silently rejects every callback. Reporting readiness only on /health means
  // the failure surfaces later, in the app, as an error about the backend.
  final missing = {
    ...sessionConfigurationErrors(config),
    ...callbackConfigurationErrors(config),
  };
  if (missing.isNotEmpty) {
    stderr.writeln('Refusing to start — .env is missing required values:');
    for (final key in missing) {
      stderr.writeln('  $key');
    }
    stderr.writeln('See example/backend/.env.example.');
    exit(1);
  }

  final store = AttemptStore();

  Timer.periodic(const Duration(minutes: 1), (_) {
    store.purgeCreatedBefore(
      DateTime.now().toUtc().subtract(
        Duration(minutes: config.checkoutStatusTtlMinutes),
      ),
    );
  });

  final handler = buildHandler(config, store);
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
    poweredByHeader: null,
  );

  logEvent(
    'server_started',
    fields: {
      'port': server.port,
      'sessionReady': sessionConfigurationErrors(config).isEmpty,
      'callbackReady': callbackConfigurationErrors(config).isEmpty,
      'routes': [
        for (final route in describeRoutes()) '${route.method} ${route.path}',
      ],
    },
  );

  // Without this, Ctrl-C leaves the listening socket (and the Timer.periodic
  // above) keeping the isolate alive, which is what makes the terminal that
  // launched this process hang on exit.
  await ProcessSignal.sigint.watch().first;
  await server.close(force: true);
  exit(0);
}
