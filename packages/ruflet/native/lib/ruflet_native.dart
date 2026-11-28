/// Ruflet's native services on Android and iOS, called directly over FFI:
/// JNI (package:jni) on Android, the Objective-C runtime
/// (package:objective_c) and C (dart:ffi) on iOS.
///
/// Register `RufletNativeExtension()` (the core features) in the app's
/// extension list. Extension features have their own entry libraries, for
/// example `package:ruflet_native/flashlight.dart`.
library ruflet_native;

export 'src/extension.dart' show RufletNativeExtension;
export 'src/feature.dart' show NativeFeature, OffPlatform;
