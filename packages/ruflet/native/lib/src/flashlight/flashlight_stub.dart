// Ported unchanged from ruflet-engine#136 (branch ffi/flashlight, 492b38b0):
// packages/ruflet_flashlight/lib/src/torch_backend_stub.dart. Only the import paths differ.

import 'flashlight_api.dart';

// Web has no dart:ffi. The Flashlight service only runs on Android and iOS,
// so this is never called; it only keeps web builds compiling.
TorchBackend createTorchBackend() =>
    throw UnsupportedError('No native torch on this platform.');
