import 'package:ruflet/ruflet.dart';

import '../feature.dart';
import 'flashlight_service.dart';

RufletService _createService(Control control) =>
    FlashlightControl(control: control);

/// Flashlight (ruflet_flashlight): the torch over JNI (CameraManager) and the
/// Objective-C runtime (AVCaptureDevice), from ruflet-engine#136.
///
/// Off Android and iOS the glue itself answers today's error (`Exception:
/// Flashlight control is supported only on Android and iOS devices.`), so
/// the feature serves the control everywhere ([OffPlatform.self]).
const flashlightFeature = NativeFeature(
  name: 'flashlight',
  controlTypes: {'Flashlight'},
  offPlatform: OffPlatform.self,
  createService: _createService,
);
