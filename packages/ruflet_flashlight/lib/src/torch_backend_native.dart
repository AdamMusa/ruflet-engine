import 'dart:io' show Platform;

import 'android_torch.dart';
import 'android_torch_jni.dart';
import 'ios_torch.dart';
import 'ios_torch_objc.dart';
import 'torch_backend.dart';

// One per isolate, so the Android camera id is looked up once, as the
// plugin looked it up once per engine.
final _android = AndroidTorchBackend(JniTorchCalls());
final _ios = IOSTorchBackend(ObjCTorchCalls());

TorchBackend createTorchBackend() {
  if (Platform.isAndroid) return _android;
  if (Platform.isIOS) return _ios;
  throw UnsupportedError('No native torch on this platform.');
}
