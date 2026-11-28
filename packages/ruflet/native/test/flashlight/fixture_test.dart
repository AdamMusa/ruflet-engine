// Replays the Flashlight fixtures recorded from torch_light 1.1.0 on the
// iOS simulator and the Android emulator against ruflet_native's glue, with
// a fake torch that answers what the device answered. Every reply must be
// the same msgpack bytes (SPEC §8.2). The real native code is replayed
// against the same fixtures on the devices (tool/ruflet_native/example).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_native/flashlight.dart';
import 'package:ruflet_native/src/flashlight/errors.dart';
import 'package:ruflet_native/src/flashlight/flashlight_api.dart';
import 'package:ruflet_native/src/flashlight/flashlight_service.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

/// Answers the recorded outcomes in call order.
class _ScriptedTorch implements TorchBackend {
  _ScriptedTorch(this.outcomes);
  final List<Object?> outcomes;
  var _next = 0;

  Future<T> _answer<T>() async {
    final outcome = outcomes[_next++];
    if (outcome is Exception) throw outcome;
    return outcome as T;
  }

  @override
  Future<bool> isTorchAvailable() => _answer<bool>();

  @override
  Future<void> enableTorch() => _answer<void>();

  @override
  Future<void> disableTorch() => _answer<void>();
}

final _torchError = RegExp(r'^\[(\w+)(?:: ([\s\S]*))?\]$');

/// torch_light's exception for a recorded error text.
Exception? _exception(String text) {
  final m = _torchError.firstMatch(text);
  if (m == null) return null;
  final message = m[2];
  return switch (m[1]) {
    'EnableTorchExistentUserException' =>
      EnableTorchExistentUserException(message: message),
    'EnableTorchException' => EnableTorchException(message: message),
    'EnableTorchNotAvailableException' =>
      EnableTorchNotAvailableException(message: message),
    'DisableTorchExistentUserException' =>
      DisableTorchExistentUserException(message: message),
    'DisableTorchException' => DisableTorchException(message: message),
    'DisableTorchNotAvailableException' =>
      DisableTorchNotAvailableException(message: message),
    _ => null,
  };
}

const _torchMethods = {'on', 'off', 'is_available'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dir = Directory('test/fixtures/flashlight');
  final files = dir.existsSync()
      ? (dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];

  test('fixtures exist for Android and iOS', () {
    expect(files.map((f) => f.uri.pathSegments.last), ['android.json', 'ios.json']);
  });

  for (final file in files) {
    final fixture = Fixture.fromJson(
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>());
    group('${fixture.platform} (${fixture.deviceClass})', () {
      setUp(() => debugDefaultTargetPlatformOverride =
          fixture.platform == 'ios' ? TargetPlatform.iOS : TargetPlatform.android);
      tearDown(() {
        debugDefaultTargetPlatformOverride = null;
        FlashlightControl.debugBackendOverride = null;
      });

      for (final recorded in fixture.cases) {
        test(recorded.spec.name, () async {
          // The native outcome of each torch call, from the recorded replies.
          final outcomes = <Object?>[];
          final invokes = recorded.spec.steps.whereType<Invoke>().toList();
          final replies =
              recorded.out.where((m) => m.action == 'invoke_method').toList();
          expect(replies, hasLength(invokes.length));
          for (var i = 0; i < invokes.length; i++) {
            if (!_torchMethods.contains(invokes[i].method)) continue;
            final payload = replies[i].payload as Map;
            final error = payload['error'] as String?;
            outcomes.add(error == null ? payload['result'] : _exception(error));
          }
          FlashlightControl.debugBackendOverride = _ScriptedTorch(outcomes);
          final harness = await WireHarness.start([Extension()]);
          final actual = await harness.run(recorded.spec);
          harness.dispose();
          expect(compareCase(recorded, actual), isEmpty);
        });
      }
    });
  }
}
