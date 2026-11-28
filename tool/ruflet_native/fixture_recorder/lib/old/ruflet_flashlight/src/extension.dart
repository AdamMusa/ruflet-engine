// ruflet_flashlight as it was at ruflet-engine a4c64d157bb16b08bf2198809ed48c4ed51531dd,
// copied verbatim below this comment: the old plugin (torch_light 1.1.0) the
// Flashlight fixtures are recorded from. Since #136 the engine's own
// ruflet_flashlight calls the torch over FFI, so the recorder keeps this copy.

import 'package:ruflet/ruflet.dart';

import 'flashlight.dart';

class Extension extends RufletExtension {
  @override
  RufletService? createService(Control control) {
    switch (control.type) {
      case "Flashlight":
        return FlashlightControl(control: control);
      default:
        return null;
    }
  }
}
