// The Android main thread: the main Looper, a Handler on it, and an Executor
// that runs on it. Flutter 3.41 runs the root isolate on the platform (main)
// thread (merged threads), so Dart code here is on the main thread and a
// Dart-implemented callback registered with the main Looper runs inline
// (package:jni blocking callbacks; SPEC §4.3 T3).
import 'package:jni/jni.dart';

import 'bindings/shared.g.dart';
import 'jni_env.dart';

/// Whether Dart runs on the Android main thread.
bool isMainThread() => Looper.mainLooper!.use((looper) => looper.isCurrentThread);

/// Fails with a clear message when Dart does not run on the main thread (an
/// app that opted out of Flutter's merged platform/UI thread; Q14).
void assertMainThread(String what) {
  if (!isMainThread()) {
    throw StateError('ruflet_native: $what must run on the Android main '
        "thread. Flutter's merged platform/UI thread is required "
        '(io.flutter.embedding.android.DisableMergedPlatformUIThread must not '
        'be true).');
  }
}

Handler? _mainHandler;

/// A Handler on the main Looper, for APIs that take a Handler.
Handler get mainHandler {
  final existing = _mainHandler;
  if (existing != null) return existing;
  final looper = Looper.mainLooper!;
  try {
    return _mainHandler = Handler.new$2(looper);
  } finally {
    looper.release();
  }
}

Executor? _mainExecutor;

/// An Executor that runs on the main thread, for APIs that take an Executor:
/// `Context.getMainExecutor()` on API 28+, otherwise one that posts to
/// [mainHandler].
Executor get mainExecutor => _mainExecutor ??= sdkInt >= 28
    ? applicationContext.mainExecutor!
    : Executor.implement($Executor(execute: (Runnable? runnable) {
        mainHandler.post(runnable);
        runnable?.release();
        wakeEventLoop();
      }));

/// A Java Runnable that runs [body] on the thread that calls it. The caller
/// keeps the returned object as long as Java may run it, then releases it.
Runnable runnable(void Function() body) => Runnable.implement($Runnable(run: () {
      try {
        body();
      } finally {
        wakeEventLoop();
      }
    }));

/// Runs [body] on the main thread on a later Looper turn (`Handler.post`).
/// Returns the Runnable so the caller can cancel it with
/// `mainHandler.removeCallbacks`; release it once it ran or was removed.
Runnable postToMain(void Function() body, {Duration? delay}) {
  final task = runnable(body);
  if (delay == null) {
    mainHandler.post(task);
  } else {
    mainHandler.postDelayed$1(task, delay.inMilliseconds);
  }
  return task;
}
