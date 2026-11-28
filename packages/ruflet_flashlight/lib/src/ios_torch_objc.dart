import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart' show calloc;
import 'package:objective_c/objective_c.dart' as objc;

import 'ios_torch.dart';

typedef _Obj = ffi.Pointer<objc.ObjCObjectImpl>;
typedef _Sel = ffi.Pointer<objc.ObjCSelector>;

// AVFoundation is a system framework; opening it registers AVCaptureDevice
// with the Objective-C runtime and gives access to AVMediaTypeVideo.
final _avFoundation = ffi.DynamicLibrary.open(
  '/System/Library/Frameworks/AVFoundation.framework/AVFoundation',
);
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
    .cast<
      ffi.NativeFunction<ffi.Bool Function(_Obj, _Sel, ffi.Pointer<_Obj>)>
    >()
    .asFunction<bool Function(_Obj, _Sel, ffi.Pointer<_Obj>)>();
final _sendLong = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Void Function(_Obj, _Sel, ffi.Long)>>()
    .asFunction<void Function(_Obj, _Sel, int)>();
final _sendVoid = objc.msgSendPointer
    .cast<ffi.NativeFunction<ffi.Void Function(_Obj, _Sel)>>()
    .asFunction<void Function(_Obj, _Sel)>();

/// [IOSTorchCalls] made directly over the Objective-C runtime.
class ObjCTorchCalls implements IOSTorchCalls {
  @override
  VideoDevice? defaultVideoDevice() {
    final device = _sendObj(_captureDevice, _selDefaultDevice, _mediaTypeVideo);
    return device == ffi.nullptr ? null : _ObjCVideoDevice(device);
  }
}

/// An AVCaptureDevice. The object is autoreleased and only used
/// synchronously within one call, before the run loop drains its pool.
class _ObjCVideoDevice implements VideoDevice {
  _ObjCVideoDevice(this._device);

  final _Obj _device;

  @override
  bool get hasTorch => _sendBool(_device, _selHasTorch);

  @override
  bool setTorchMode(int mode) {
    final error = calloc<_Obj>();
    try {
      if (!_sendBoolError(_device, _selLock, error)) return false;
      _sendLong(_device, _selSetTorchMode, mode);
      _sendVoid(_device, _selUnlock);
      return true;
    } finally {
      calloc.free(error);
    }
  }
}
