import 'dart:io' show Platform;

import 'android_torch.dart';
import 'ios_torch.dart';
import 'torch_backend.dart';

TorchBackend createTorchBackend() {
  if (Platform.isAndroid) return AndroidTorchBackend();
  if (Platform.isIOS) return IOSTorchBackend();
  throw UnsupportedError('No native torch on this platform.');
}
