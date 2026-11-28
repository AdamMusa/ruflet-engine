// Replays a feature's recorded fixture (old plugin) against ruflet_native on
// this device and compares the wire messages (SPEC §8.1, §8.3).
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

/// `android` or `ios`.
String get platformName => Platform.isAndroid ? 'android' : 'ios';

/// This device's class and description, as the recorder writes them
/// (tool/ruflet_native/fixture_recorder/lib/recorder.dart).
Future<({String deviceClass, String device})> describeDevice() async {
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final a = await info.androidInfo;
    return (
      deviceClass: a.isPhysicalDevice ? 'android-device' : 'android-emulator',
      device: '${a.manufacturer} ${a.model}, Android ${a.version.release} '
          '(API ${a.version.sdkInt}, ${a.supportedAbis.first})',
    );
  }
  final i = await info.iosInfo;
  return (
    deviceClass: i.isPhysicalDevice ? 'ios-device' : 'ios-simulator',
    device: '${i.name} (${i.utsname.machine}), ${i.systemName} '
        '${i.systemVersion}',
  );
}

/// The fixture recorded for [feature] on this platform, or null.
Future<Fixture?> loadFixture(String feature) async {
  try {
    final text = await rootBundle.loadString('fixtures/$feature.$platformName.json');
    return Fixture.fromJson((jsonDecode(text) as Map).cast<String, Object?>());
  } on FlutterError {
    return null;
  }
}

/// The result of a replay.
class Replay {
  Replay(this.fixture, this.sameDevice, this.problems, this.outputs);
  final Fixture fixture;

  /// Whether this is the device the fixture was recorded on (model, OS and
  /// ABI): then every non-volatile message must match byte for byte;
  /// otherwise only actions, order and Dart types are compared, because
  /// results such as "no torch" depend on the device.
  final bool sameDevice;

  /// Differences from the recording.
  final List<String> problems;

  /// What each case sent, by case name.
  final Map<String, List<WireMessage>> outputs;
}

/// Replays every case of [fixture] through a real backend with
/// [extensions] and compares (see [Replay.sameDevice]).
Future<Replay> replay(Fixture fixture, List<RufletExtension> extensions) async {
  final same = fixture.device == (await describeDevice()).device;
  final harness = await WireHarness.start(extensions);
  final problems = <String>[];
  final outputs = <String, List<WireMessage>>{};
  try {
    for (final recorded in fixture.cases) {
      final actual = await harness.run(recorded.spec);
      outputs[recorded.spec.name] = actual;
      problems.addAll(compareCase(recorded, actual, shapeOnly: !same));
    }
  } finally {
    harness.dispose();
  }
  return Replay(fixture, same, problems, outputs);
}
