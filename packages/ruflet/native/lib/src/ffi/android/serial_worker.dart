// The Android serial worker: a long-lived helper isolate running blocking JNI
// work (KeyStore/Cipher, file copies, AudioRecord loops) in FIFO order.
//
// package:jni attaches the worker's thread to the JVM on first use. Java
// objects cross isolates only as global-reference addresses that the task
// takes over and releases. Never implement a Java interface in a worker for
// callbacks delivered on the main thread: the main thread would block on the
// worker (SPEC §4.3 T6).
import '../common/serial_worker.dart';

/// A [SerialWorker] for Android work.
class AndroidSerialWorker {
  AndroidSerialWorker(String name) : _worker = SerialWorker(name);

  final SerialWorker _worker;

  /// Runs [task] in the worker after every task submitted before it.
  Future<T> run<T>(T Function() task) => _worker.run(task);

  Future<void> close() => _worker.close();
}
