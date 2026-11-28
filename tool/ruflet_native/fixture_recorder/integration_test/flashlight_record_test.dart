// Records the Flashlight fixtures from ruflet_flashlight with torch_light
// 1.1.0 (the old plugin).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruflet_flashlight/ruflet_flashlight.dart' as old;
import 'package:ruflet_native_fixture_recorder/recorder.dart';
import 'package:ruflet_native_wire/wire_harness.dart';

/// The calls Ruby sends: page.flashlight.on / off / is_available (page.rb
/// FlashlightService), plus an unknown method and ignored arguments.
const flashlightCases = <CaseSpec>[
  CaseSpec(
      name: 'is_available',
      control: {'_c': 'Flashlight', '_i': 101},
      steps: [Invoke('is_available')]),
  CaseSpec(
      name: 'on',
      control: {'_c': 'Flashlight', '_i': 102},
      steps: [Invoke('on')]),
  CaseSpec(
      name: 'off',
      control: {'_c': 'Flashlight', '_i': 103},
      steps: [Invoke('off')]),
  CaseSpec(
      name: 'on_off_on_error_prop',
      control: {'_c': 'Flashlight', '_i': 104, 'on_error': true},
      steps: [Invoke('on'), Invoke('off'), Invoke('is_available')]),
  CaseSpec(
      name: 'args_are_ignored',
      control: {'_c': 'Flashlight', '_i': 105},
      steps: [
        Invoke('on', args: {'unused': 1}),
        Invoke('off', args: <String, Object?>{}),
      ]),
  CaseSpec(
      name: 'unknown_method',
      control: {'_c': 'Flashlight', '_i': 106},
      steps: [Invoke('blink')]),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('record flashlight', (tester) async {
    final fixture = await record(
      binding: binding,
      feature: 'flashlight',
      extensions: [old.Extension()],
      cases: flashlightCases,
      recordedWith: {
        'packages': {'ruflet_flashlight': 'engine a4c64d15', 'torch_light': '1.1.0'},
        'flutter': '3.41.2',
      },
    );
    expect(fixture.cases, hasLength(flashlightCases.length));
  });
}
