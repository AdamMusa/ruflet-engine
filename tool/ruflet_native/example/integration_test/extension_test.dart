// RufletNativeExtension on the device: the native path is taken, the
// merged-thread check passes, inert stubs leave every core service to the
// core, and the flashlight entry serves only Flashlight.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruflet_native/flashlight.dart' as flashlight;
import 'package:ruflet_native/ruflet_native.dart';
import 'package:ruflet_native/src/ffi/runtime.dart';
import 'package:ruflet_native/src/glue/platform.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Android/iOS path, with the merged thread', (t) async {
    expect(isNativeTarget, isTrue);
    ensureNativeRuntime();
  });

  testWidgets('stubs leave the core services to the core', (t) async {
    final harness =
        await WireHarness.start([RufletNativeExtension(), flashlight.Extension()]);
    for (final type in ['Battery', 'Clipboard', 'Connectivity', 'StoragePaths']) {
      expect(harness.mount({'_c': type, '_i': type.length + 900}), isNull,
          reason: type);
    }
    final out = await harness.run(const CaseSpec(
        name: 'flashlight served',
        control: {'_c': 'Flashlight', '_i': 950},
        steps: [Invoke('blink')]));
    expect((out.single.payload as Map)['error'],
        'Exception: Unknown Flashlight method: blink');
    harness.dispose();
  });
}
