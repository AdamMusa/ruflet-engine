import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart' show androidApplicationContext;

import 'torch_backend.dart';
import 'torch_exceptions.dart';

/// The torch on Android, through android.hardware.camera2.CameraManager,
/// called directly over JNI.
///
/// It follows torch_light 1.1.0's TorchLightPlugin.kt step for step: the
/// first camera id is looked up once, a missing id means "Torch is not
/// available", and a CameraAccessException means another camera user.
class AndroidTorchBackend implements TorchBackend {
  static final _contextClass = JClass.forName('android/content/Context');
  static final _getSystemService = _contextClass.instanceMethodId(
      'getSystemService', '(Ljava/lang/String;)Ljava/lang/Object;');
  static final _getPackageManager = _contextClass.instanceMethodId(
      'getPackageManager', '()Landroid/content/pm/PackageManager;');

  static final _hasSystemFeature =
      JClass.forName('android/content/pm/PackageManager')
          .instanceMethodId('hasSystemFeature', '(Ljava/lang/String;)Z');

  static final _cameraManagerClass =
      JClass.forName('android/hardware/camera2/CameraManager');
  static final _getCameraIdList = _cameraManagerClass.instanceMethodId(
      'getCameraIdList', '()[Ljava/lang/String;');
  static final _setTorchMode = _cameraManagerClass.instanceMethodId(
      'setTorchMode', '(Ljava/lang/String;Z)V');

  static final _cameraAccessException =
      JClass.forName('android/hardware/camera2/CameraAccessException');
  static final _exceptionClass = JClass.forName('java/lang/Exception');
  static final _objectToString = JClass.forName('java/lang/Object')
      .instanceMethodId('toString', '()Ljava/lang/String;');

  // Context.CAMERA_SERVICE and PackageManager.FEATURE_CAMERA_FLASH.
  static const _cameraService = 'camera';
  static const _featureCameraFlash = 'android.hardware.camera.flash';

  static JObject? _cameraManager;
  static String? _cameraId;
  static bool _cameraIdLooked = false;

  static JObject get _manager => _cameraManager ??= using<JObject>((arena) {
        final name = _cameraService.toJString()..releasedBy(arena);
        return _getSystemService.call(
            androidApplicationContext, JObject.type, [name]);
      });

  /// The first camera id, looked up once as the plugin did when it attached.
  /// Any failure (no camera, no permission to list them) leaves it null.
  static String? get _firstCameraId {
    if (!_cameraIdLooked) {
      _cameraIdLooked = true;
      try {
        final ids = _getCameraIdList.call(_manager, JObject.type, [])
            as JArray<JString?>;
        try {
          final first = ids.length > 0 ? ids[0] : null;
          _cameraId = first?.toDartString(releaseOriginal: true);
        } finally {
          ids.release();
        }
      } catch (_) {
        _cameraId = null;
      }
    }
    return _cameraId;
  }

  /// What Kotlin's "$e" printed: the Java exception's own toString().
  static String _javaText(JThrowable e) =>
      _objectToString.call(e, JString.type, []).toDartString(
          releaseOriginal: true);

  @override
  Future<bool> isTorchAvailable() async {
    final packageManager =
        _getPackageManager.call(androidApplicationContext, JObject.type, []);
    try {
      return using((arena) {
        final feature = _featureCameraFlash.toJString()..releasedBy(arena);
        return _hasSystemFeature
            .call(packageManager, jboolean.type, [feature]);
      });
    } finally {
      packageManager.release();
    }
  }

  void _setTorch(bool on) {
    final id = _firstCameraId!;
    using((arena) {
      final jid = id.toJString()..releasedBy(arena);
      _setTorchMode.call(_manager, jvoid.type, [jid, on]);
    });
  }

  @override
  Future<void> enableTorch() async {
    if (_firstCameraId == null) {
      throw EnableTorchNotAvailableException(message: 'Torch is not available');
    }
    try {
      _setTorch(true);
    } on JThrowable catch (e) {
      if (e.isInstanceOf(_cameraAccessException)) {
        throw EnableTorchExistentUserException(
            message:
                'There is an existent camera user, cannot enable torch: '
                '${_javaText(e)}');
      }
      if (e.isInstanceOf(_exceptionClass)) {
        throw EnableTorchException(
            message: 'Could not enable torch: ${_javaText(e)}');
      }
      rethrow;
    }
  }

  @override
  Future<void> disableTorch() async {
    if (_firstCameraId == null) {
      throw DisableTorchNotAvailableException(
          message: 'Torch is not available');
    }
    try {
      _setTorch(false);
    } on JThrowable catch (e) {
      if (e.isInstanceOf(_cameraAccessException)) {
        throw DisableTorchExistentUserException(
            message:
                'There is an existent camera user, cannot disable torch: '
                '${_javaText(e)}');
      }
      if (e.isInstanceOf(_exceptionClass)) {
        throw DisableTorchException(message: 'Could not disable torch');
      }
      rethrow;
    }
  }
}
