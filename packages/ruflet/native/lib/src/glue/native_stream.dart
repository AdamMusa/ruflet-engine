// Native callbacks become the same Dart events an EventChannel delivered
// (SPEC §5.1).
import 'dart:async';

/// A broadcast stream over one native subscription.
///
/// - The first listener starts the native subscription ([onStart]: register
///   a listener, add an observer, start a monitor or poller); the last
///   cancel stops it ([onStop]).
/// - Values are delivered asynchronously on the event queue (`Timer.run`),
///   on a later event-loop turn as an EventChannel event arrived, so an
///   event never overtakes the reply of the call that caused it (E8). A
///   value queued by a native subscription that stopped before delivery is
///   dropped, also when a new listener started the next one meanwhile.
/// - [initialValue], when given, is emitted once when the native
///   subscription starts, so only the first listener gets it: an
///   EventChannel's onListen ran once per broadcast stream (battery_plus,
///   connectivity_plus and sensors_plus share one stream per platform
///   instance), so a second Ruflet service subscribing later got no initial
///   event.
///
/// The native callback copies what it needs into Dart values before calling
/// [add]: callback arguments are only valid during the callback (T4).
class NativeStream<T> {
  NativeStream({required this.onStart, required this.onStop, this.initialValue});

  /// Starts the native subscription; [add] and [addError] feed it.
  final void Function(NativeStream<T> stream) onStart;

  /// Stops the native subscription.
  final void Function() onStop;

  /// The value emitted when the native subscription starts, if any.
  final T Function()? initialValue;

  late final StreamController<T> _controller = StreamController<T>.broadcast(
      onListen: _listen, onCancel: _cancel);

  bool _running = false;

  /// Counts native subscriptions, so that a value queued by a stopped one
  /// never reaches the listeners of the next.
  int _session = 0;

  /// The events.
  Stream<T> get stream => _controller.stream;

  /// Whether the native subscription runs.
  bool get isRunning => _running;

  void _listen() {
    _running = true;
    _session++;
    onStart(this);
    final initial = initialValue;
    if (initial != null) {
      final value = initial();
      _later(() => _controller.add(value));
    }
  }

  void _cancel() {
    if (!_running) return;
    _running = false;
    onStop();
  }

  /// Runs [deliver] on a later event-loop turn if the native subscription
  /// that is running now still runs then.
  void _later(void Function() deliver) {
    if (!_running) return;
    final session = _session;
    Timer.run(() {
      if (_running && session == _session) deliver();
    });
  }

  /// Delivers [value] on a later event-loop turn.
  void add(T value) => _later(() => _controller.add(value));

  /// Delivers [error] on a later event-loop turn.
  void addError(Object error, [StackTrace? stackTrace]) =>
      _later(() => _controller.addError(error, stackTrace));
}
