/// Host-side driver for the web integration tests — required because web
/// integration tests only run through `flutter drive`.
library;

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
