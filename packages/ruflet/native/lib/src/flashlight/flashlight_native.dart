// Ported unchanged from ruflet-engine#136 (branch ffi/flashlight, 492b38b0):
// packages/ruflet_flashlight/lib/src/torch_backend_native.dart. Only the import paths differ.

import 'dart:io' show Platform;

import 'flashlight_android.dart';
import 'flashlight_ios.dart';
import 'flashlight_api.dart';

TorchBackend createTorchBackend() {
  if (Platform.isAndroid) return AndroidTorchBackend();
  if (Platform.isIOS) return IOSTorchBackend();
  throw UnsupportedError('No native torch on this platform.');
}
