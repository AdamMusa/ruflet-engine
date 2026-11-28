// Pins every error the native torch code throws (exception class and
// message text) to torch_light 1.1.0, because the engine replies
// `e.toString()` to Ruby. The device replays compare these texts byte for
// byte only on the recording device, and CI's devices are other ones (and
// the Android emulators have a flash, so Android's error branches never run
// there). This host test reads the sources, so CI catches any changed text.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

typedef _Throw = (String exception, String message);

/// torch_light 1.1.0, android/src/main/kotlin/com/svprdga/torchlight/
/// TorchLightPlugin.kt (result.error codes mapped to exceptions by
/// lib/torch_light.dart). Kotlin's "$e" is the Java toString(), _javaText.
const _android = <_Throw>[
  // enableTorch: cameraId == null
  ('EnableTorchNotAvailableException', 'Torch is not available'),
  // enableTorch: catch (e: CameraAccessException)
  (
    'EnableTorchExistentUserException',
    r'There is an existent camera user, cannot enable torch: ${_javaText(e)}'
  ),
  // enableTorch: catch (e: Exception)
  ('EnableTorchException', r'Could not enable torch: ${_javaText(e)}'),
  // disableTorch: cameraId == null
  ('DisableTorchNotAvailableException', 'Torch is not available'),
  // disableTorch: catch (e: CameraAccessException)
  (
    'DisableTorchExistentUserException',
    r'There is an existent camera user, cannot disable torch: ${_javaText(e)}'
  ),
  // disableTorch: catch (e: Exception)
  ('DisableTorchException', 'Could not disable torch'),
];

/// torch_light 1.1.0, ios/Classes/SwiftTorchLightPlugin.swift.
const _ios = <_Throw>[
  // isTorchAvailable: no AVCaptureDevice (torch_available_error)
  (
    'EnableTorchException',
    'Could not determine if the device has a torch, please make sure that '
        'you are doing this on a real device.'
  ),
  // enableTorch: no AVCaptureDevice
  (
    'EnableTorchException',
    'Could not enable torch, please make sure that you are doing this on a '
        'real device'
  ),
  // enableTorch: !device.hasTorch
  ('EnableTorchNotAvailableException', 'Torch is not available'),
  // enableTorch: lockForConfiguration threw
  ('EnableTorchExistentUserException', 'Could not enable torch: '),
  // disableTorch: no AVCaptureDevice
  (
    'DisableTorchException',
    'Could not disable torch, please make sure that you are doing this on a '
        'real device'
  ),
  // disableTorch: !device.hasTorch
  ('DisableTorchNotAvailableException', 'Torch is not available'),
  // disableTorch: lockForConfiguration threw
  ('DisableTorchExistentUserException', 'Could not disable torch'),
];

final _throwSite = RegExp(
    r'''throw\s+(\w+)\(\s*message:\s*((?:'(?:[^'\\]|\\.)*'\s*)+)\)''');
final _literal = RegExp(r"""'((?:[^'\\]|\\.)*)'""");

/// The `throw X(message: '...' '...')` sites of [path], in source order,
/// with adjacent literals joined (interpolations kept as written).
List<_Throw> _throws(String path) => [
      for (final m in _throwSite.allMatches(File(path).readAsStringSync()))
        (
          m[1]!,
          _literal.allMatches(m[2]!).map((l) => l[1]!).join(),
        ),
    ];

/// Every recorded torch error text of [platform]'s fixture.
List<String> _recordedErrors(String platform) {
  final text =
      File('test/fixtures/flashlight/$platform.json').readAsStringSync();
  final found = <String>{};
  void walk(Object? value) {
    if (value is String && RegExp(r'^\[\w+Torch\w*Exception').hasMatch(value)) {
      found.add(value);
    } else if (value is Map) {
      value.values.forEach(walk);
    } else if (value is List) {
      value.forEach(walk);
    }
  }

  walk(jsonDecode(text));
  return found.toList()..sort();
}

/// Whether [pin] produces [recorded] (torch_light's `[Name: message]`); an
/// interpolated tail matches any text.
bool _produces(_Throw pin, String recorded) {
  final (exception, message) = pin;
  final hole = message.indexOf(r'${');
  final prefix = '[$exception: ${hole < 0 ? message : message.substring(0, hole)}';
  return hole < 0 ? recorded == '$prefix]' : recorded.startsWith(prefix);
}

void main() {
  test('Android throws torch_light 1.1.0 texts', () {
    expect(_throws('lib/src/flashlight/flashlight_android.dart'), _android);
  });

  test('iOS throws torch_light 1.1.0 texts', () {
    expect(_throws('lib/src/flashlight/flashlight_ios.dart'), _ios);
  });

  for (final (platform, pins) in [('android', _android), ('ios', _ios)]) {
    test('every error recorded from torch_light on $platform is pinned', () {
      for (final recorded in _recordedErrors(platform)) {
        expect(pins.any((pin) => _produces(pin, recorded)), isTrue,
            reason: recorded);
      }
    });
  }

  test('the pins are not vacuous', () {
    expect(_recordedErrors('ios'), hasLength(3));
    expect(_produces(_ios[1],
            '[EnableTorchException: Could not enable torch, please make sure '
            'that you are doing this on a real device]'),
        isTrue);
    expect(_produces(_android[1],
            '[EnableTorchExistentUserException: There is an existent camera '
            'user, cannot enable torch: android.hardware.camera2.'
            'CameraAccessException: CAMERA_IN_USE (4)]'),
        isTrue);
    expect(_produces(_ios[3], '[EnableTorchExistentUserException: Could not]'),
        isFalse);
  });
}
