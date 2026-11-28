import 'package:flutter/foundation.dart' show debugPrint;

import 'torch_backend.dart';
import 'torch_exceptions.dart';

/// A java.lang.Exception thrown by one of the [AndroidTorchCalls].
class JavaException implements Exception {
  JavaException(this.text, {this.message, this.isCameraAccess = false});

  /// The exception's own toString(), which Kotlin's "$e" printed.
  final String text;

  /// Its getMessage(), which a MethodChannel error carried.
  final String? message;

  /// Whether it is an android.hardware.camera2.CameraAccessException.
  final bool isCameraAccess;

  @override
  String toString() => text;
}

/// The Android calls the torch needs. The real ones go over JNI
/// (android_torch_jni.dart); tests use a fake.
///
/// A Java Exception comes back as a [JavaException]. Any other Throwable (a
/// java.lang.Error) passes through unchanged.
abstract class AndroidTorchCalls {
  /// CameraManager.getCameraIdList().
  List<String?> cameraIdList();

  /// CameraManager.setTorchMode(cameraId, enabled).
  void setTorchMode(String cameraId, bool enabled);

  /// PackageManager.hasSystemFeature(FEATURE_CAMERA_FLASH), on the app
  /// context's package manager.
  bool hasFlashFeature();
}

/// The torch on Android, through android.hardware.camera2.CameraManager.
///
/// It follows torch_light 1.1.0's TorchLightPlugin.kt step for step: the
/// first camera id is looked up once, a missing id means "Torch is not
/// available", and a CameraAccessException means another camera user.
class AndroidTorchBackend implements TorchBackend {
  AndroidTorchBackend(this._calls);

  final AndroidTorchCalls _calls;
  String? _cameraId;
  bool _cameraIdLooked = false;

  /// The first camera id, looked up once, as the plugin did when it attached
  /// to the engine. Any failure (no camera, no permission to list them)
  /// leaves it null for good, and is logged as the plugin logged it.
  String? get _firstCameraId {
    if (!_cameraIdLooked) {
      _cameraIdLooked = true;
      _cameraId = _lookUpCameraId();
    }
    return _cameraId;
  }

  String? _lookUpCameraId() {
    Object? error;
    try {
      final ids = _calls.cameraIdList();
      if (ids.isNotEmpty && ids.first != null) return ids.first;
      error = 'no camera found';
    } catch (e) {
      error = e;
    }
    debugPrint(
      "Flashlight: could not fetch camera id, the torch won't "
      "work: $error",
    );
    return null;
  }

  @override
  Future<bool> isTorchAvailable() async {
    try {
      return _calls.hasFlashFeature();
    } on JavaException catch (e) {
      // The MethodChannel replied a Java exception as an error with its
      // message, and torch_light turned every error into this one.
      throw EnableTorchException(message: e.message);
    }
  }

  @override
  Future<void> enableTorch() async {
    final id = _firstCameraId;
    if (id == null) {
      throw EnableTorchNotAvailableException(message: 'Torch is not available');
    }
    try {
      _calls.setTorchMode(id, true);
    } on JavaException catch (e) {
      if (e.isCameraAccess) {
        throw EnableTorchExistentUserException(
          message:
              'There is an existent camera user, cannot enable torch: '
              '${e.text}',
        );
      }
      throw EnableTorchException(message: 'Could not enable torch: ${e.text}');
    }
  }

  @override
  Future<void> disableTorch() async {
    final id = _firstCameraId;
    if (id == null) {
      throw DisableTorchNotAvailableException(
        message: 'Torch is not available',
      );
    }
    try {
      _calls.setTorchMode(id, false);
    } on JavaException catch (e) {
      if (e.isCameraAccess) {
        throw DisableTorchExistentUserException(
          message:
              'There is an existent camera user, cannot disable torch: '
              '${e.text}',
        );
      }
      throw DisableTorchException(message: 'Could not disable torch');
    }
  }
}
