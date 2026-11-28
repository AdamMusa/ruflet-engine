// The torch contract of the Flashlight feature, from ruflet-engine#136
// (packages/ruflet_flashlight/lib/src/torch_backend.dart), plus the instance
// the glue calls and its test override.
import 'package:flutter/foundation.dart';

import 'flashlight_select.dart' as platform;

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

  /// Replaces the platform torch in tests.
  @visibleForTesting
  static TorchBackend? debugOverride;

  static TorchBackend? _platform;

  /// The torch the Flashlight glue calls: [debugOverride], or the platform
  /// backend, created on first use.
  static TorchBackend get instance =>
      debugOverride ?? (_platform ??= forPlatform());
}
