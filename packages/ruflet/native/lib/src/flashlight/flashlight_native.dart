// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/torch_backend_native.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// ruflet-native-glue: replace=import 'android_torch_jni.dart';=>import 'flashlight_android.dart';
// ruflet-native-glue: replace=import 'ios_torch_objc.dart';=>import 'flashlight_ios.dart';
// ruflet-native-glue: replace=import 'torch_backend.dart';=>import 'flashlight_api.dart';
// The Android and iOS backends, one per isolate.
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'dart:io' show Platform;

import 'android_torch.dart';
import 'flashlight_android.dart';
import 'ios_torch.dart';
import 'flashlight_ios.dart';
import 'flashlight_api.dart';

// One per isolate, so the Android camera id is looked up once, as the
// plugin looked it up once per engine.
final _android = AndroidTorchBackend(JniTorchCalls());
final _ios = IOSTorchBackend(ObjCTorchCalls());

TorchBackend createTorchBackend() {
  if (Platform.isAndroid) return _android;
  if (Platform.isIOS) return _ios;
  throw UnsupportedError('No native torch on this platform.');
}
