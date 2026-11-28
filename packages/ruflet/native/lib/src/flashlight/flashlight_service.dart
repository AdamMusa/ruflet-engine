// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/flashlight.dart
// ruflet-native-glue: commit=a4c64d157bb16b08bf2198809ed48c4ed51531dd
// ruflet-native-glue: replace=import 'package:torch_light/torch_light.dart';=>import 'flashlight_api.dart';
// ruflet-native-glue: replace=TorchLight.=>TorchBackend.instance.
// The Flashlight service glue: today's service file, copied verbatim with the
// substitutions above (tool/ruflet_native/check_glue_drift.sh diffs it).

import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'flashlight_api.dart';

class FlashlightControl extends RufletService {
  FlashlightControl({required super.control});

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
          await TorchBackend.instance.enableTorch();
        case "off":
          await TorchBackend.instance.disableTorch();
        case "is_available":
          return await TorchBackend.instance.isTorchAvailable();
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
