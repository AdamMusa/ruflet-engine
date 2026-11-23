import 'torch_backend_stub.dart'
    if (dart.library.ffi) 'torch_backend_native.dart' as platform;

/// The device torch, reached directly through the platform's own API.
///
/// Each method answers or throws exactly what torch_light 1.1.0 did, using
/// the exceptions in torch_exceptions.dart.
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
