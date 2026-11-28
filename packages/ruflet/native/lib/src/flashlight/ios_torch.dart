// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/ios_torch.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// ruflet-native-glue: replace=import 'torch_backend.dart';=>import 'flashlight_api.dart';
// ruflet-native-glue: replace=import 'torch_exceptions.dart';=>import 'errors.dart';
// ruflet-native-glue: replace=(ios_torch_objc.dart)=>(flashlight_ios.dart)
// The iOS torch logic (torch_light 1.1.0's SwiftTorchLightPlugin) over the
// IOSTorchCalls seam. Plain Dart: tests run it with a fake.
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'flashlight_api.dart';
import 'errors.dart';

/// AVCaptureTorchMode.off and AVCaptureTorchMode.on.
const avCaptureTorchModeOff = 0;
const avCaptureTorchModeOn = 1;

/// One AVCaptureDevice.
abstract class VideoDevice {
  /// AVCaptureDevice.hasTorch.
  bool get hasTorch;

  /// lockForConfiguration, set torchMode to [mode], unlockForConfiguration.
  /// False when the lock fails, where Swift's `try` threw.
  bool setTorchMode(int mode);
}

/// The iOS calls the torch needs. The real ones go over the Objective-C
/// runtime (flashlight_ios.dart); tests use a fake.
abstract class IOSTorchCalls {
  /// `AVCaptureDevice.default(for: .video)`, or null (for example on the
  /// simulator).
  VideoDevice? defaultVideoDevice();
}

/// The torch on iOS, through AVCaptureDevice.
///
/// It follows torch_light 1.1.0's SwiftTorchLightPlugin step for step,
/// including its messages.
class IOSTorchBackend implements TorchBackend {
  IOSTorchBackend(this._calls);

  final IOSTorchCalls _calls;

  @override
  Future<bool> isTorchAvailable() async {
    final device = _calls.defaultVideoDevice();
    if (device == null) {
      throw EnableTorchException(
        message:
            'Could not determine if the device has a torch, please '
            'make sure that you are doing this on a real device.',
      );
    }
    return device.hasTorch;
  }

  @override
  Future<void> enableTorch() async {
    final device = _calls.defaultVideoDevice();
    if (device == null) {
      throw EnableTorchException(
        message:
            'Could not enable torch, please make sure that you are '
            'doing this on a real device',
      );
    }
    if (!device.hasTorch) {
      throw EnableTorchNotAvailableException(message: 'Torch is not available');
    }
    if (!device.setTorchMode(avCaptureTorchModeOn)) {
      throw EnableTorchExistentUserException(
        message: 'Could not enable torch: ',
      );
    }
  }

  @override
  Future<void> disableTorch() async {
    final device = _calls.defaultVideoDevice();
    if (device == null) {
      throw DisableTorchException(
        message:
            'Could not disable torch, please make sure that you are '
            'doing this on a real device',
      );
    }
    if (!device.hasTorch) {
      throw DisableTorchNotAvailableException(
        message: 'Torch is not available',
      );
    }
    if (!device.setTorchMode(avCaptureTorchModeOff)) {
      throw DisableTorchExistentUserException(
        message: 'Could not disable torch',
      );
    }
  }
}
