// The FFI layer on platforms with dart:ffi. Only Android and iOS reach it
// (isNativeTarget); desktop builds tree-shake it away.
import 'dart:io' show Platform;

import '../glue/platform.dart';
import 'android/main_thread.dart' as android;
import 'ios/main_queue.dart' as ios;

bool _checked = false;

/// Checks once that Dart runs on the platform thread (Flutter's merged
/// platform/UI thread, the default on 3.41 for Android and iOS), which every
/// feature requires (SPEC §4.3 T1, owner question Q14).
void ensureNativeRuntime() {
  if (_checked) return;
  if (isNativeTargetOverridden) return;
  _checked = true;
  if (Platform.isAndroid) {
    android.assertMainThread('ruflet_native');
  } else if (Platform.isIOS) {
    ios.assertMainThread('ruflet_native');
  }
}
