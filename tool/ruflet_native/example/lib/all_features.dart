// Imports every ruflet_native library, entry libraries included, and
// registers every feature. CI compiles it for the web
// (`flutter build web -t lib/all_features.dart`) to prove that the web never
// imports dart:ffi, jni or objective_c (SPEC §9).
import 'package:flutter/material.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native/audio.dart' as audio;
import 'package:ruflet_native/audio_recorder.dart' as audio_recorder;
import 'package:ruflet_native/camera.dart' as camera;
import 'package:ruflet_native/flashlight.dart' as flashlight;
import 'package:ruflet_native/geolocator.dart' as geolocator;
import 'package:ruflet_native/local_auth.dart' as local_auth;
import 'package:ruflet_native/permission_handler.dart' as permission_handler;
import 'package:ruflet_native/qrcode_scanner.dart' as qrcode_scanner;
import 'package:ruflet_native/ruflet_native.dart';
import 'package:ruflet_native/secure_storage.dart' as secure_storage;
import 'package:ruflet_native/video.dart' as video;

void main() {
  final extensions = <RufletExtension>[
    RufletNativeExtension(),
    audio.Extension(),
    audio_recorder.Extension(),
    camera.Extension(),
    flashlight.Extension(),
    geolocator.Extension(),
    local_auth.Extension(),
    permission_handler.Extension(),
    qrcode_scanner.Extension(),
    secure_storage.Extension(),
    video.Extension(),
  ];
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://all-features'),
      assetsDir: '',
      extensions: extensions,
      multiView: false);
  for (final extension in backend.extensions) {
    extension.ensureInitialized();
    extension.createService(
        Control(id: 1, type: 'Flashlight', properties: {}, backend: backend));
  }
  runApp(MaterialApp(home: Text('${backend.extensions.length} extensions')));
}
