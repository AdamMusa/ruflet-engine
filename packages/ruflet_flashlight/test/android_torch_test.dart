// ruflet-coverage: Flashlight
//
// The Android backend's branches, through the Flashlight service, with the
// JNI calls replaced by a fake. Each expected reply is what torch_light
// 1.1.0's TorchLightPlugin.kt and its Dart side made of the same case.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_flashlight/src/android_torch.dart';
import 'package:ruflet_flashlight/src/flashlight.dart';

import 'torch_test_support.dart';

/// CameraManager and PackageManager as the backend sees them.
class _FakeAndroid implements AndroidTorchCalls {
  List<String?> cameraIds = ['0', '1'];
  Object? cameraIdError;
  Object? torchError;
  bool flash = true;
  Object? flashError;

  int cameraIdLookups = 0;
  final torchModes = <(String, bool)>[];

  @override
  List<String?> cameraIdList() {
    cameraIdLookups++;
    if (cameraIdError != null) throw cameraIdError!;
    return cameraIds;
  }

  @override
  void setTorchMode(String cameraId, bool enabled) {
    torchModes.add((cameraId, enabled));
    if (torchError != null) throw torchError!;
  }

  @override
  bool hasFlashFeature() {
    if (flashError != null) throw flashError!;
    return flash;
  }
}

/// Stands in for a java.lang.Error, which is not a java.lang.Exception.
class _JavaError implements Exception {
  @override
  String toString() => 'Exception in Java: java.lang.OutOfMemoryError';
}

// The text of the CameraAccessException the emulator throws while another
// app holds the camera.
const _inUse =
    'android.hardware.camera2.CameraAccessException: '
    'CAMERA_IN_USE (4): setTorchMode:3030: Torch for camera "1" is not '
    'available due to an existing camera user';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAndroid android;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    android = _FakeAndroid();
    FlashlightControl.debugBackendOverride = AndroidTorchBackend(android);
  });

  tearDown(() {
    FlashlightControl.debugBackendOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('on and off set the torch of the first camera and reply nil', () async {
    final control = startService('Flashlight');
    expect(await control.invokeMethod('on', null, invokeTimeout), isNull);
    expect(await control.invokeMethod('off', null, invokeTimeout), isNull);
    expect(android.torchModes, [('0', true), ('0', false)]);
  });

  test('the camera id is looked up once and kept', () async {
    final control = startService('Flashlight');
    await control.invokeMethod('on', null, invokeTimeout);
    android.cameraIds = ['5'];
    await control.invokeMethod('off', null, invokeTimeout);
    await control.invokeMethod('on', null, invokeTimeout);
    expect(android.cameraIdLookups, 1);
    expect(android.torchModes, [('0', true), ('0', false), ('0', true)]);
  });

  test('no camera: the torch is not available, and stays so', () async {
    final logs = captureDebugPrint();
    android.cameraIds = [];
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchNotAvailableException: Torch is not available]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchNotAvailableException: Torch is not available]',
    );
    // Looked up once, like the plugin did when it attached to the engine.
    android.cameraIds = ['0'];
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchNotAvailableException: Torch is not available]',
    );
    expect(android.cameraIdLookups, 1);
    expect(android.torchModes, isEmpty);
    expect(
      logs.where((l) => l.contains('could not fetch camera id')).toList(),
      [
        "Flashlight: could not fetch camera id, the torch won't work: "
            'no camera found',
      ],
    );
  });

  test('a failed camera id lookup is not available and logs why', () async {
    final logs = captureDebugPrint();
    android.cameraIdError = JavaException(
      'java.lang.SecurityException: no access',
    );
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchNotAvailableException: Torch is not available]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchNotAvailableException: Torch is not available]',
    );
    expect(android.torchModes, isEmpty);
    expect(
      logs.where((l) => l.contains('could not fetch camera id')).toList(),
      [
        "Flashlight: could not fetch camera id, the torch won't work: "
            'java.lang.SecurityException: no access',
      ],
    );
  });

  test('a CameraAccessException is an existent camera user', () async {
    android.torchError = JavaException(
      _inUse,
      message:
          'CAMERA_IN_USE (4): setTorchMode:3030: Torch for camera '
          '"1" is not available due to an existing camera user',
      isCameraAccess: true,
    );
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchExistentUserException: There is an existent camera '
      'user, cannot enable torch: $_inUse]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchExistentUserException: There is an existent camera '
      'user, cannot disable torch: $_inUse]',
    );
  });

  test('any other Java exception: enable says why, disable does not', () async {
    android.torchError = JavaException(
      'java.lang.IllegalArgumentException: bad id',
      message: 'bad id',
    );
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchException: Could not enable torch: '
      'java.lang.IllegalArgumentException: bad id]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchException: Could not disable torch]',
    );
  });

  test('a Java Error is not caught as an exception', () async {
    android.torchError = _JavaError();
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      'Exception in Java: java.lang.OutOfMemoryError',
    );
    expect(
      await invokeError(control, 'off'),
      'Exception in Java: java.lang.OutOfMemoryError',
    );
  });

  test('is_available replies whether the device has a camera flash', () async {
    final control = startService('Flashlight');
    android.flash = true;
    expect(
      await control.invokeMethod('is_available', null, invokeTimeout),
      true,
    );
    android.flash = false;
    expect(
      await control.invokeMethod('is_available', null, invokeTimeout),
      false,
    );
    expect(android.cameraIdLookups, 0);
  });

  test('is_available failures come back as EnableTorchException', () async {
    final control = startService('Flashlight');
    android.flashError = JavaException(
      'java.lang.RuntimeException: Package manager has died',
      message: 'Package manager has died',
    );
    expect(
      await invokeError(control, 'is_available'),
      '[EnableTorchException: Package manager has died]',
    );
    android.flashError = JavaException('java.lang.NullPointerException');
    expect(
      await invokeError(control, 'is_available'),
      '[EnableTorchException]',
    );
  });
}
