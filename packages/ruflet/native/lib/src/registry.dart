// Every planned ruflet_native feature, complete from PR 1. A feature PR
// replaces only its own lib/src/<feature>/feature.dart stub; this file is
// edited again only to add a new feature.
//
// Unreferenced feature constants are tree-shaken with all their code, so an
// app carries only the features its registered extensions reference.
import 'feature.dart';

import 'audio/feature.dart';
import 'audio_recorder/feature.dart';
import 'battery/feature.dart';
import 'camera/feature.dart';
import 'clipboard/feature.dart';
import 'connectivity/feature.dart';
import 'device_info/feature.dart';
import 'file_picker/feature.dart';
import 'flashlight/feature.dart';
import 'geolocator/feature.dart';
import 'haptic_feedback/feature.dart';
import 'local_auth/feature.dart';
import 'permission_handler/feature.dart';
import 'qrcode_scanner/feature.dart';
import 'screen_brightness/feature.dart';
import 'secure_storage/feature.dart';
import 'sensors/feature.dart';
import 'shake_detector/feature.dart';
import 'share/feature.dart';
import 'shared_preferences/feature.dart';
import 'storage_paths/feature.dart';
import 'url_launcher/feature.dart';
import 'video/feature.dart';
import 'wakelock/feature.dart';

/// The features of the core package's services: what `RufletNativeExtension()`
/// registers. Equal to android/features/CORE.
const coreFeatures = <NativeFeature>[
  batteryFeature,
  connectivityFeature,
  clipboardFeature,
  shareFeature,
  urlLauncherFeature,
  sharedPreferencesFeature,
  storagePathsFeature,
  filePickerFeature,
  sensorsFeature,
  shakeDetectorFeature,
  screenBrightnessFeature,
  wakelockFeature,
  hapticFeedbackFeature,
  deviceInfoFeature,
];

/// The features of the extension packages (ruflet_<name>): each has its own
/// entry library, lib/<name>.dart, imported only by its wrapper package.
const extensionFeatures = <NativeFeature>[
  flashlightFeature,
  secureStorageFeature,
  localAuthFeature,
  geolocatorFeature,
  permissionHandlerFeature,
  audioFeature,
  audioRecorderFeature,
  cameraFeature,
  qrcodeScannerFeature,
  videoFeature,
];

/// Every feature (the example app and the tests register these).
const allFeatures = <NativeFeature>[...coreFeatures, ...extensionFeatures];
