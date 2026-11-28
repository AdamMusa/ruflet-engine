// Polling for Android events whose only platform API is an abstract class
// (BroadcastReceiver, NetworkCallback, ContentObserver), which Dart cannot
// subclass over JNI (owner question Q2).
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Reads a value every [period] and once more right after the app resumes,
/// and reports it when it changed (or every read, with `distinctOnly:
/// false`).
class Poller<T> {
  Poller({
    required this.read,
    required this.onValue,
    this.period = const Duration(seconds: 1),
    this.distinctOnly = true,
    this.equals,
  });

  /// Reads the current value synchronously (on the main thread).
  final T Function() read;

  /// Receives each reported value.
  final void Function(T value) onValue;

  final Duration period;

  /// Report only values that differ from the previous one.
  final bool distinctOnly;

  /// Equality for [distinctOnly]; `==` by default.
  final bool Function(T a, T b)? equals;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _hasValue = false;
  late T _last;

  bool get isRunning => _timer != null;

  /// Starts polling. With [emitNow], the current value is reported on the
  /// next event-loop turn (as an EventChannel's first event was).
  void start({bool emitNow = true}) {
    if (_timer != null) return;
    _timer = Timer.periodic(period, (_) => poll());
    _lifecycle = AppLifecycleListener(onResume: poll);
    if (emitNow) Timer.run(() => poll(force: true));
  }

  /// Reads once and reports per [distinctOnly]; [force] always reports.
  void poll({bool force = false}) {
    if (_timer == null) return;
    final value = read();
    final same = _hasValue &&
        (equals?.call(_last, value) ?? _last == value);
    _hasValue = true;
    _last = value;
    if (force || !distinctOnly || !same) onValue(value);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _hasValue = false;
  }
}
