// ruflet_flashlight as it was at ruflet-engine a4c64d157bb16b08bf2198809ed48c4ed51531dd,
// copied verbatim below this comment: the old plugin (torch_light 1.1.0) the
// Flashlight fixtures are recorded from. Since #136 the engine's own
// ruflet_flashlight calls the torch over FFI, so the recorder keeps this copy.

import 'package:ruflet/ruflet.dart';
import 'package:flutter/widgets.dart';
import 'package:torch_light/torch_light.dart';

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
          await TorchLight.enableTorch();
        case "off":
          await TorchLight.disableTorch();
        case "is_available":
          return await TorchLight.isTorchAvailable();
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
