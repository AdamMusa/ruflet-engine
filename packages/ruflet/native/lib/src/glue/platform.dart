import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether ruflet_native's FFI implementations run here: Android or iOS,
/// never web, desktop or a host test.
///
/// `Platform.isAndroid` / `Platform.isIOS` are `vm:platform-const`, so an AOT
/// build folds this to a constant and drops the other OS's code; desktop
/// builds drop both. The test override exists only outside release builds.
bool get isNativeTarget {
  if (!kReleaseMode && debugNativeTargetOverride != null) {
    return debugNativeTargetOverride!;
  }
  return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}

/// Whether a test set [debugNativeTargetOverride] (never in release builds).
bool get isNativeTargetOverridden =>
    !kReleaseMode && debugNativeTargetOverride != null;

/// Makes host tests take the Android/iOS path of [isNativeTarget] (true) or
/// the off-platform path (false). Null uses the real platform.
@visibleForTesting
bool? debugNativeTargetOverride;
