import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for `integration_test/`. Writes every `takeScreenshot` call to
/// `screenshots/<name>.png` next to the project so the captures survive the
/// test run.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('screenshots/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
