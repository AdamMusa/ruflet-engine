// ruflet-native-glue: source=packages/ruflet_flashlight/lib/src/torch_backend_stub.dart
// ruflet-native-glue: commit=5a314c9fdf0780cc689a946b84e600540a02d9ae
// ruflet-native-glue: replace=import 'torch_backend.dart';=>import 'flashlight_api.dart';
// What web builds compile instead of flashlight_native.dart.
// Copied verbatim, with the substitutions above, from ruflet_flashlight
// as ruflet-engine#136 merged it. tool/ruflet_native/check_glue_drift.sh
// diffs it against the source, so a fix there must be copied here.

import 'flashlight_api.dart';

// Web has no dart:ffi. The Flashlight service only runs on Android and iOS,
// so this is never called; it only keeps web builds compiling.
TorchBackend createTorchBackend() =>
    throw UnsupportedError('No native torch on this platform.');
