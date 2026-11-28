import 'torch_backend.dart';
import 'torch_exceptions.dart';

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
/// runtime (ios_torch_objc.dart); tests use a fake.
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
