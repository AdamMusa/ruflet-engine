// ruflet-coverage: Flashlight
//
// The iOS backend's branches, through the Flashlight service, with the
// Objective-C calls replaced by a fake. Each expected reply is what
// torch_light 1.1.0's SwiftTorchLightPlugin and its Dart side made of the
// same case.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_flashlight/src/flashlight.dart';
import 'package:ruflet_flashlight/src/ios_torch.dart';

import 'torch_test_support.dart';

/// An AVCaptureDevice.
class _FakeDevice implements VideoDevice {
  @override
  bool hasTorch = true;
  bool lockSucceeds = true;
  final torchModes = <int>[];

  @override
  bool setTorchMode(int mode) {
    if (!lockSucceeds) return false;
    torchModes.add(mode);
    return true;
  }
}

class _FakeIOS implements IOSTorchCalls {
  _FakeDevice? device = _FakeDevice();
  int lookups = 0;

  @override
  VideoDevice? defaultVideoDevice() {
    lookups++;
    return device;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeIOS ios;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    ios = _FakeIOS();
    FlashlightControl.debugBackendOverride = IOSTorchBackend(ios);
  });

  tearDown(() {
    FlashlightControl.debugBackendOverride = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('on and off set torchMode .on (1) and .off (0) and reply nil', () async {
    final control = startService('Flashlight');
    expect(await control.invokeMethod('on', null, invokeTimeout), isNull);
    expect(await control.invokeMethod('off', null, invokeTimeout), isNull);
    expect(ios.device!.torchModes, [1, 0]);
  });

  test(
    'every call asks AVCaptureDevice for the default video device again',
    () async {
      final control = startService('Flashlight');
      await control.invokeMethod('on', null, invokeTimeout);
      await control.invokeMethod('off', null, invokeTimeout);
      await control.invokeMethod('is_available', null, invokeTimeout);
      expect(ios.lookups, 3);
    },
  );

  test('is_available replies hasTorch', () async {
    final control = startService('Flashlight');
    expect(
      await control.invokeMethod('is_available', null, invokeTimeout),
      true,
    );
    ios.device!.hasTorch = false;
    expect(
      await control.invokeMethod('is_available', null, invokeTimeout),
      false,
    );
  });

  test('no video device (the simulator) asks for a real device', () async {
    ios.device = null;
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'is_available'),
      '[EnableTorchException: Could not determine if the device has a '
      'torch, please make sure that you are doing this on a real '
      'device.]',
    );
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchException: Could not enable torch, please make sure '
      'that you are doing this on a real device]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchException: Could not disable torch, please make sure '
      'that you are doing this on a real device]',
    );
  });

  test('no torch: the torch is not available', () async {
    ios.device!.hasTorch = false;
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchNotAvailableException: Torch is not available]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchNotAvailableException: Torch is not available]',
    );
    expect(ios.device!.torchModes, isEmpty);
  });

  test('a failed lockForConfiguration is an existent camera user', () async {
    ios.device!.lockSucceeds = false;
    final control = startService('Flashlight');
    expect(
      await invokeError(control, 'on'),
      '[EnableTorchExistentUserException: Could not enable torch: ]',
    );
    expect(
      await invokeError(control, 'off'),
      '[DisableTorchExistentUserException: Could not disable torch]',
    );
  });
}
