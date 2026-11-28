// A long-lived helper isolate that runs tasks one at a time, in the order
// they were submitted (SPEC §4.1 / §4.3 T6).
//
// Blocking native work never runs on the platform thread: it would freeze
// rendering, the in-process Ruby bridge and every other invoke. Where the
// old plugin ran work on one serial queue or HandlerThread, the feature uses
// one SerialWorker, so operations keep their order. One `Isolate.run` per
// call would not: two calls could overtake each other.
import 'dart:async';
import 'dart:isolate';

/// Runs closures in one helper isolate, FIFO.
///
/// A task runs in another isolate of the same group: it may capture only
/// sendable values (no open ports, no native resources of the caller), and
/// it may not touch the caller's static state. Native objects cross as
/// addresses (JNI global references, retained Objective-C pointers) that the
/// task owns and releases.
class SerialWorker {
  SerialWorker(this.name);

  /// Shown as the isolate's debug name.
  final String name;

  Future<SendPort>? _port;
  Isolate? _isolate;
  bool _closed = false;

  Future<SendPort> _spawn() async {
    final ready = ReceivePort();
    _isolate = await Isolate.spawn(_main, ready.sendPort,
        debugName: 'ruflet_native:$name');
    return await ready.first as SendPort;
  }

  /// Runs [task] in the worker after every task submitted before it.
  Future<T> run<T>(FutureOr<T> Function() task) async {
    if (_closed) throw StateError('SerialWorker $name is closed');
    final port = await (_port ??= _spawn());
    final reply = ReceivePort();
    port.send((task, reply.sendPort));
    final (ok, value, stack) =
        await reply.first as (bool, Object?, String?);
    reply.close();
    if (ok) return value as T;
    Error.throwWithStackTrace(
        value!, stack == null ? StackTrace.empty : StackTrace.fromString(stack));
  }

  /// Stops the worker once the tasks already submitted have run.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final port = _port;
    if (port == null) return;
    final exit = ReceivePort();
    _isolate?.addOnExitListener(exit.sendPort);
    (await port).send(null);
    await exit.first;
    exit.close();
  }

  static Future<void> _main(SendPort ready) async {
    final inbox = ReceivePort();
    ready.send(inbox.sendPort);
    await for (final message in inbox) {
      if (message == null) break;
      final (task, reply) = message as (FutureOr<Object?> Function(), SendPort);
      try {
        reply.send((true, await task(), null));
      } catch (error, stack) {
        try {
          reply.send((false, error, stack.toString()));
        } catch (_) {
          // The error object itself cannot cross isolates.
          reply.send(
              (false, RemoteError(error.toString(), '$stack'), stack.toString()));
        }
      }
    }
    inbox.close();
  }
}
