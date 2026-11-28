// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/android_torch_jni.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// The AndroidTorchCalls over JNI (package:jni).
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart' show androidApplicationContext;

import 'android_torch.dart';

/// [AndroidTorchCalls] made directly over JNI.
class JniTorchCalls implements AndroidTorchCalls {
  static final _contextClass = JClass.forName('android/content/Context');
  static final _getSystemService = _contextClass.instanceMethodId(
    'getSystemService',
    '(Ljava/lang/String;)Ljava/lang/Object;',
  );
  static final _getPackageManager = _contextClass.instanceMethodId(
    'getPackageManager',
    '()Landroid/content/pm/PackageManager;',
  );

  static final _hasSystemFeature = JClass.forName(
    'android/content/pm/PackageManager',
  ).instanceMethodId('hasSystemFeature', '(Ljava/lang/String;)Z');

  static final _cameraManagerClass = JClass.forName(
    'android/hardware/camera2/CameraManager',
  );
  static final _getCameraIdList = _cameraManagerClass.instanceMethodId(
    'getCameraIdList',
    '()[Ljava/lang/String;',
  );
  static final _setTorchMode = _cameraManagerClass.instanceMethodId(
    'setTorchMode',
    '(Ljava/lang/String;Z)V',
  );

  static final _cameraAccessException = JClass.forName(
    'android/hardware/camera2/CameraAccessException',
  );
  static final _exceptionClass = JClass.forName('java/lang/Exception');
  static final _getMessage = JClass.forName(
    'java/lang/Throwable',
  ).instanceMethodId('getMessage', '()Ljava/lang/String;');

  // Context.CAMERA_SERVICE and PackageManager.FEATURE_CAMERA_FLASH.
  static const _cameraService = 'camera';
  static const _featureCameraFlash = 'android.hardware.camera.flash';

  /// Kept for the life of the process, as the plugin kept its CameraManager.
  JObject? _cameraManager;

  /// Runs [body] with the application context, then releases the new
  /// reference androidApplicationContext returns.
  static R _withContext<R>(R Function(JObject context) body) {
    final context = androidApplicationContext;
    try {
      return body(context);
    } finally {
      context.release();
    }
  }

  JObject get _manager => _cameraManager ??= _withContext<JObject>(
    (context) => using((arena) {
      final name = _cameraService.toJString()..releasedBy(arena);
      return _getSystemService.call(context, JObject.type, [name]);
    }),
  );

  /// Runs [body]. A Java Exception it throws becomes a [JavaException], and
  /// its reference is released. Other Throwables pass through unchanged.
  static T _java<T>(T Function() body) {
    try {
      return body();
    } on JThrowable catch (e) {
      if (!e.isInstanceOf(_exceptionClass)) rethrow;
      final error = JavaException(
        // jni fills JThrowable.message with the exception's toString().
        e.message,
        message: _getMessage
            .callNullable(e, JString.type, [])
            ?.toDartString(releaseOriginal: true),
        isCameraAccess: e.isInstanceOf(_cameraAccessException),
      );
      e.release();
      throw error;
    }
  }

  @override
  List<String?> cameraIdList() => _java(() {
    final ids =
        _getCameraIdList.call(_manager, JObject.type, []) as JArray<JString?>;
    try {
      return [
        for (var i = 0; i < ids.length; i++)
          ids[i]?.toDartString(releaseOriginal: true),
      ];
    } finally {
      ids.release();
    }
  });

  @override
  void setTorchMode(String cameraId, bool enabled) => _java(() {
    using((arena) {
      final id = cameraId.toJString()..releasedBy(arena);
      _setTorchMode.call(_manager, jvoid.type, [id, enabled]);
    });
  });

  @override
  bool hasFlashFeature() => _java(
    () => _withContext((context) {
      final packageManager = _getPackageManager.call(context, JObject.type, []);
      try {
        return using((arena) {
          final feature = _featureCameraFlash.toJString()..releasedBy(arena);
          return _hasSystemFeature.call(packageManager, jboolean.type, [
            feature,
          ]);
        });
      } finally {
        packageManager.release();
      }
    }),
  );
}
