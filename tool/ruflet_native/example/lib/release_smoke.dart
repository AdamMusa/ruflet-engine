// ignore_for_file: implementation_imports
// Release-mode smoke test (SPEC §8.3, spike S6): flutter_driver cannot run
// release builds, so this entry runs the checks at startup and prints one
// line per check, which ../release_smoke.sh reads from the device log:
//   flutter build apk --release -t lib/release_smoke.dart
// On Android this proves that R8 keeps every class and member the shared
// layer reaches only over JNI.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ruflet_native/flashlight.dart' as flashlight;
import 'package:ruflet_native/ruflet_native.dart';
import 'package:ruflet_native/src/ffi/android/activity_binding.dart';
import 'package:ruflet_native/src/ffi/android/bindings/shared.g.dart';
import 'package:ruflet_native/src/ffi/android/main_thread.dart' as android;
import 'package:ruflet_native/src/ffi/ios/async_blocks.dart';
import 'package:ruflet_native/src/ffi/ios/main_queue.dart' as ios;
import 'package:ruflet_native/src/ffi/ios/msg.dart';
import 'package:ruflet_native/src/flashlight/flashlight_api.dart';

void _say(String check, Object? result) =>
    debugPrint('RUFLET_NATIVE_SMOKE $check: $result');

Future<void> _check(String name, FutureOr<Object?> Function() body) async {
  try {
    _say(name, 'ok ${await body()}');
  } catch (e) {
    _say(name, 'FAILED $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('smoke')))));
  await Future<void>.delayed(const Duration(seconds: 1));
  for (final extension in [RufletNativeExtension(), flashlight.Extension()]) {
    extension.ensureInitialized();
  }
  await _check('torch is_available', () async {
    try {
      return await TorchBackend.forPlatform().isTorchAvailable();
    } on Exception catch (e) {
      return e.toString();
    }
  });
  if (Platform.isAndroid) {
    await _check('main thread', android.isMainThread);
    await _check('runnable called directly', () {
      var ran = false;
      final task = android.runnable(() => ran = true);
      task.run();
      task.release();
      return ran;
    });
    await _check('handler post returns', () {
      final task = android.runnable(() => _say('posted runnable', 'ran'));
      return android.mainHandler.post(task);
    });
    await _check('handler post', () async {
      final done = Completer<bool>();
      final task = android.postToMain(() => done.complete(android.isMainThread()));
      try {
        return await done.future.timeout(const Duration(seconds: 5));
      } finally {
        task.release();
      }
    });
    await _check('executor', () async {
      final done = Completer<bool>();
      final task = android.runnable(() => done.complete(android.isMainThread()));
      android.mainExecutor.execute(task);
      try {
        return await done.future.timeout(const Duration(seconds: 5));
      } finally {
        task.release();
      }
    });
    await _check('activity binding', () {
      final binding = ActivityBinding.instance;
      return 'attached=${binding.attached.value}';
    });
    await _check('permission result', () => ActivityBinding.instance
        .requestPermissions(['android.permission.READ_CALENDAR'])
        .timeout(const Duration(seconds: 10)));
  } else if (Platform.isIOS) {
    await _check('main thread', ios.isMainThread);
    await _check('async block from the run loop', () {
      final done = Completer<bool>();
      final block = AsyncBlock.voidCallback(() => done.complete(ios.isMainThread()));
      msgVoidObj(ios.mainOperationQueue, sel('addOperationWithBlock:'), block.pointer);
      return done.future.timeout(const Duration(seconds: 5));
    });
  }
  _say('done', 'ok');
}
