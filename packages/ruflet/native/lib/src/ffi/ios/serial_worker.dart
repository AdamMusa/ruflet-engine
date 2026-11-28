// The iOS serial worker: each task runs in a helper isolate, in FIFO order,
// inside its own autorelease pool (a helper isolate's thread has no run
// loop draining one).
import 'package:objective_c/objective_c.dart' as objc;

import '../common/serial_worker.dart';

/// A long-lived helper isolate for blocking Objective-C/C work (Keychain
/// SecItem calls, file copies). Objects cross isolates only as retained
/// addresses.
class IosSerialWorker {
  IosSerialWorker(String name) : _worker = SerialWorker(name);

  final SerialWorker _worker;

  /// Runs [task] synchronously in the worker, inside an autorelease pool.
  Future<T> run<T>(T Function() task) =>
      _worker.run(() => objc.autoReleasePool(task));

  Future<void> close() => _worker.close();
}
