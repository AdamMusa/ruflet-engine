// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/torch_backend.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// ruflet-native-glue: replace=torch_backend_stub.dart=>flashlight_stub.dart
// ruflet-native-glue: replace=torch_backend_native.dart=>flashlight_native.dart
// ruflet-native-glue: replace=torch_exceptions.dart=>errors.dart
// The torch contract (SPEC §3.2).
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'flashlight_stub.dart'
    if (dart.library.ffi) 'flashlight_native.dart' as platform;

/// The device torch, reached directly through the platform's own API.
///
/// Each method answers or throws exactly what torch_light 1.1.0 did, using
/// the exceptions in errors.dart.
abstract class TorchBackend {
  /// Whether the device has a torch.
  Future<bool> isTorchAvailable();

  /// Turns the torch on.
  Future<void> enableTorch();

  /// Turns the torch off.
  Future<void> disableTorch();

  /// The backend for the current platform: JNI on Android, the
  /// Objective-C runtime on iOS. Other platforms never reach it, because the
  /// Flashlight service only runs on Android and iOS.
  static TorchBackend forPlatform() => platform.createTorchBackend();
}
