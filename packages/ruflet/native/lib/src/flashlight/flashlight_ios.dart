// Ported unchanged from ruflet-engine#136 (branch ffi/flashlight, 492b38b0):
// packages/ruflet_flashlight/lib/src/ios_torch.dart. Only the import paths differ.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' show calloc;
import 'package:objective_c/objective_c.dart' as objc;

import 'flashlight_api.dart';
import 'errors.dart';

typedef _Obj = ffi.Pointer<objc.ObjCObjectImpl>;
typedef _Sel = ffi.Pointer<objc.ObjCSelector>;

// AVFoundation is a system framework; opening it registers AVCaptureDevice
// with the Objective-C runtime and gives access to AVMediaTypeVideo.
final _avFoundation = ffi.DynamicLibrary.open(
    '/System/Library/Frameworks/AVFoundation.framework/AVFoundation');
final _mediaTypeVideo = _avFoundation.lookup<_Obj>('AVMediaTypeVideo').value;
final _captureDevice = objc.getClass('AVCaptureDevice');

final _selDefaultDevice = objc.registerName('defaultDeviceWithMediaType:');
final _selHasTorch = objc.registerName('hasTorch');
final _selLock = objc.registerName('lockForConfiguration:');
final _selSetTorchMode = objc.registerName('setTorchMode:');
final _selUnlock = objc.registerName('unlockForConfiguration');

final _sendObj = objc.msgSendPointer
    .cast<ffi.NativeFunction<_Obj Function(_Obj, _Sel, _Obj)>>()
    .asFunction<_Obj Function(_Obj, _Sel, _Obj)>();
final _sendBool = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Bool Function(_Obj, _Sel)>>()
    .asFunction<bool Function(_Obj, _Sel)>();
final _sendBoolError = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Bool Function(_Obj, _Sel, ffi.Pointer<_Obj>)>>()
    .asFunction<bool Function(_Obj, _Sel, ffi.Pointer<_Obj>)>();
final _sendLong = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Void Function(_Obj, _Sel, ffi.Long)>>()
    .asFunction<void Function(_Obj, _Sel, int)>();
final _sendVoid = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Void Function(_Obj, _Sel)>>()
    .asFunction<void Function(_Obj, _Sel)>();

// AVCaptureTorchMode.
const _torchModeOff = 0;
const _torchModeOn = 1;

/// The torch on iOS, through AVCaptureDevice, called directly over the
/// Objective-C runtime.
///
/// It follows torch_light 1.1.0's SwiftTorchLightPlugin step for step,
/// including its messages.
class IOSTorchBackend implements TorchBackend {
  /// `AVCaptureDevice.default(for: .video)`, or null (for example on the
  /// simulator). The object is autoreleased and only used synchronously
  /// within one call, before the run loop drains its pool.
  static _Obj? _defaultVideoDevice() {
    final device =
        _sendObj(_captureDevice, _selDefaultDevice, _mediaTypeVideo);
    return device == ffi.nullptr ? null : device;
  }

  /// lockForConfiguration, set the mode, unlock. False when the lock fails,
  /// where Swift's `try` threw.
  static bool _setTorchMode(_Obj device, int mode) {
    final error = calloc<_Obj>();
    try {
      if (!_sendBoolError(device, _selLock, error)) return false;
      _sendLong(device, _selSetTorchMode, mode);
      _sendVoid(device, _selUnlock);
      return true;
    } finally {
      calloc.free(error);
    }
  }

  @override
  Future<bool> isTorchAvailable() async {
    final device = _defaultVideoDevice();
    if (device == null) {
      throw EnableTorchException(
          message: 'Could not determine if the device has a torch, please '
              'make sure that you are doing this on a real device.');
    }
    return _sendBool(device, _selHasTorch);
  }

  @override
  Future<void> enableTorch() async {
    final device = _defaultVideoDevice();
    if (device == null) {
      throw EnableTorchException(
          message: 'Could not enable torch, please make sure that you are '
              'doing this on a real device');
    }
    if (!_sendBool(device, _selHasTorch)) {
      throw EnableTorchNotAvailableException(message: 'Torch is not available');
    }
    if (!_setTorchMode(device, _torchModeOn)) {
      throw EnableTorchExistentUserException(
          message: 'Could not enable torch: ');
    }
  }

  @override
  Future<void> disableTorch() async {
    final device = _defaultVideoDevice();
    if (device == null) {
      throw DisableTorchException(
          message: 'Could not disable torch, please make sure that you are '
              'doing this on a real device');
    }
    if (!_sendBool(device, _selHasTorch)) {
      throw DisableTorchNotAvailableException(
          message: 'Torch is not available');
    }
    if (!_setTorchMode(device, _torchModeOff)) {
      throw DisableTorchExistentUserException(
          message: 'Could not disable torch');
    }
  }
}
