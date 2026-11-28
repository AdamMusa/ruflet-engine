// The main thread, the main dispatch queue and the main operation queue.
//
// Flutter 3.41 runs the root isolate on the platform (main) thread on iOS
// (merged threads), so Dart code there may call UIKit directly and receive
// callbacks that Apple delivers on the main queue (SPEC §4.3 T1/T5).
import 'dart:ffi';

import 'msg.dart';

/// `[NSThread isMainThread]`.
bool isMainThread() => msgBool(cls('NSThread'), sel('isMainThread'));

/// `[NSOperationQueue mainQueue]`, for APIs that take an NSOperationQueue
/// (notification observers, CoreMotion handlers).
Obj get mainOperationQueue =>
    msgObj(cls('NSOperationQueue'), sel('mainQueue'));

/// `dispatch_get_main_queue()`, which is the address of `_dispatch_main_q`.
final Pointer<Void> mainDispatchQueue =
    DynamicLibrary.process().lookup<Void>('_dispatch_main_q');

/// Fails with a clear message when Dart does not run on the main thread
/// (an app that opted out of Flutter's merged platform/UI thread; Q14).
void assertMainThread(String what) {
  if (!isMainThread()) {
    throw StateError('ruflet_native: $what must run on the iOS main thread. '
        "Flutter's merged platform/UI thread is required "
        '(FLTEnableMergedPlatformUIThread must not be NO).');
  }
}
