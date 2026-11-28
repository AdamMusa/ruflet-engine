// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/flashlight.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// ruflet-native-glue: replace=import 'torch_backend.dart';=>import 'flashlight_api.dart';
// The Flashlight service glue: the extension's service file.
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'package:flutter/foundation.dart';
import 'package:ruflet/ruflet.dart';

import 'flashlight_api.dart';

class FlashlightControl extends RufletService {
  FlashlightControl({required super.control});

  /// Replaces the platform torch in tests.
  @visibleForTesting
  static TorchBackend? debugBackendOverride;

  TorchBackend? _backend;
  TorchBackend get _torch =>
      _backend ??= debugBackendOverride ?? TorchBackend.forPlatform();

  @override
  void init() {
    super.init();
    debugPrint("Flashlight(${control.id}).init: ${control.properties}");
    control.addInvokeMethodListener(_invokeMethod);
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    debugPrint("Flashlight.$name($args)");
    if (isMobilePlatform()) {
      switch (name) {
        case "on":
          await _torch.enableTorch();
        case "off":
          await _torch.disableTorch();
        case "is_available":
          return await _torch.isTorchAvailable();
        default:
          throw Exception("Unknown Flashlight method: $name");
      }
    } else {
      throw Exception(
          "Flashlight control is supported only on Android and iOS devices.");
    }
  }

  @override
  void dispose() {
    debugPrint("Flashlight(${control.id}).dispose");
    control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }
}
