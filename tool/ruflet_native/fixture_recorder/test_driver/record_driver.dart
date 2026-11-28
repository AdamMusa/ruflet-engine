// Host side of the recorder: writes each reported fixture under
// packages/ruflet/native/test/.
//
//   cd tool/ruflet_native/fixture_recorder
//   flutter drive --driver=test_driver/record_driver.dart \
//     --target=integration_test/<feature>_record_test.dart -d <device>
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
      responseDataCallback: (data) async {
        if (data == null) return;
        final root = Directory.current.uri.resolve('../../../packages/ruflet/native/test/');
        for (final entry in data.entries) {
          final file = File.fromUri(root.resolve(entry.key));
          await file.parent.create(recursive: true);
          await file.writeAsString(entry.value as String);
          stdout.writeln('wrote ${file.path}');
        }
      },
    );
