// The Android environment of the root isolate: application context, engine
// id, and the current activity, used per call.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:jni/jni.dart';
import 'package:jni_flutter/jni_flutter.dart' as jni_flutter;

import 'bindings/shared.g.dart';

Context? _context;

/// The application context. A long-lived global reference: safe to keep and
/// to use from any thread (jni_flutter).
Context get applicationContext =>
    _context ??= jni_flutter.androidApplicationContext.as(Context.type);

/// The id of this isolate's Flutter engine
/// (`FlutterEngine.engineForId(engineId)`).
int get engineId {
  final id = PlatformDispatcher.instance.engineId;
  if (id == null) {
    throw StateError('ruflet_native: no Flutter engine id; it is available '
        'only in the root isolate of a Flutter engine.');
  }
  return id;
}

/// Runs [body] with the current activity, synchronously, then releases it.
/// Returns null when no activity is attached.
///
/// The activity can be destroyed at any moment (rotation, backgrounding), so
/// it is fetched per use and never held across an `await` (jni_flutter's
/// contract). [body] must not be async.
T? withActivity<T>(T Function(Activity activity) body) {
  final activity = jni_flutter.androidActivity(engineId);
  if (activity == null) return null;
  final typed = activity.as(Activity.type, releaseOriginal: true);
  try {
    return body(typed);
  } finally {
    typed.release();
  }
}

/// `Build.VERSION.SDK_INT`.
int get sdkInt => Build$VERSION.SDK_INT;

/// Releases every non-null object in [objects] (callback arguments, temporary
/// results), so no JNI global reference waits for a finalizer (SPEC §4.3 T4).
void releaseAll(Iterable<JObject?> objects) {
  for (final object in objects) {
    if (object != null && !object.isReleased) object.release();
  }
}

void _noop() {}

/// Ends every Dart entry from a Java callback (S6 finding).
///
/// package:jni runs a Dart-implemented Java method inline on the main
/// thread, outside any Flutter task. Microtasks that the callback schedules
/// (a Completer.complete, a Future continuation) wait in Flutter's microtask
/// queue until the next task of the UI task runner, and an idle release app
/// may run none for seconds. A zero timer is a real event: it makes Flutter
/// run a task, which flushes those microtasks right away.
void wakeEventLoop() => Timer.run(_noop);
