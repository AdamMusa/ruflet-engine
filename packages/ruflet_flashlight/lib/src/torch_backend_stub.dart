import 'torch_backend.dart';

// Web has no dart:ffi. The Flashlight service only runs on Android and iOS,
// so this is never called; it only keeps web builds compiling.
TorchBackend createTorchBackend() =>
    throw UnsupportedError('No native torch on this platform.');
