// Flashlight over FFI on the device: replays the fixtures recorded from
// torch_light 1.1.0 and checks the native backend is the FFI one.
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruflet_native/flashlight.dart' as flashlight;
import 'package:ruflet_native/src/flashlight/flashlight_android.dart';
import 'package:ruflet_native/src/flashlight/flashlight_api.dart';
import 'package:ruflet_native/src/flashlight/flashlight_ios.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

import 'support/replay.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the torch backend is the FFI one', (tester) async {
    final backend = TorchBackend.instance;
    expect(backend,
        Platform.isAndroid ? isA<AndroidTorchBackend>() : isA<IOSTorchBackend>());
  });

  testWidgets('replies and errors match the torch_light fixtures',
      (tester) async {
    final fixture = await loadFixture('flashlight');
    expect(fixture, isNotNull,
        reason: 'no fixtures/flashlight.$platformName.json; record it with '
            'tool/ruflet_native/fixture_recorder');
    final result = await replay(fixture!, [flashlight.Extension()]);
    for (final entry in result.outputs.entries) {
      // ignore: avoid_print
      print('flashlight ${entry.key}:\n${describe(entry.value)}');
    }
    // ignore: avoid_print
    print('flashlight: compared '
        '${result.sameDevice ? 'byte for byte' : 'by shape'} against '
        '${fixture.device}');
    expect(result.problems, isEmpty, reason: result.problems.join('\n'));
  });
}
