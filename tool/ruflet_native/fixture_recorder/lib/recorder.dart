import 'package:device_info_plus/device_info_plus.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

/// `android` or `ios`.
String get platformName => Platform.isAndroid ? 'android' : 'ios';

/// The device class and description fixtures carry.
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

/// Runs [cases] against the OLD [extensions] and reports the fixture to the
/// driver, which writes it to packages/ruflet/native/test/fixtures/.
Future<Fixture> record({
  required IntegrationTestWidgetsFlutterBinding binding,
  required String feature,
  required List<RufletExtension> extensions,
  required List<CaseSpec> cases,
  required Map<String, Object?> recordedWith,
}) async {
  final device = await describeDevice();
  final harness = await WireHarness.start(extensions);
  final recorded = <FixtureCase>[];
  for (final spec in cases) {
    recorded.add(FixtureCase(spec, await harness.run(spec)));
  }
  harness.dispose();
  final fixture = Fixture(
    feature: feature,
    platform: platformName,
    deviceClass: device.deviceClass,
    device: device.device,
    recordedWith: recordedWith,
    cases: recorded,
  );
  binding.reportData = {
    'fixtures/$feature/$platformName.json': fixture.encode(),
  };
  return fixture;
}
