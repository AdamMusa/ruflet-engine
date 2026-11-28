import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_native/src/glue/native_stream.dart';

void main() {
  test('the first listener starts, the last cancel stops', () async {
    var starts = 0, stops = 0;
    final stream = NativeStream<int>(onStart: (_) => starts++, onStop: () => stops++);
    final a = stream.stream.listen((_) {});
    final b = stream.stream.listen((_) {});
    expect(starts, 1);
    await a.cancel();
    expect(stops, 0);
    await b.cancel();
    expect(stops, 1);
    expect(stream.isRunning, isFalse);
  });

  test('values arrive on a later event-loop turn, in order', () async {
    late NativeStream<int> native;
    native = NativeStream<int>(onStart: (_) {}, onStop: () {});
    final seen = <String>[];
    final sub = native.stream.listen((v) => seen.add('event $v'));
    native.add(1);
    native.add(2);
    seen.add('after add');
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['after add', 'event 1', 'event 2']);
    await sub.cancel();
  });

  test('values arrive after the microtasks of the turn that added them',
      () async {
    // An EventChannel event arrived on a later event-loop turn, so it came
    // after every microtask of the current turn (for example the reply
    // future of the call that caused it, E8). A broadcast controller's own
    // asynchronous delivery is a microtask and would come first.
    final native = NativeStream<int>(onStart: (_) {}, onStop: () {});
    final seen = <String>[];
    final sub = native.stream.listen((v) => seen.add('event $v'));
    native.add(1);
    scheduleMicrotask(() => seen.add('microtask'));
    await Future<void>.delayed(Duration.zero);
    expect(seen, ['microtask', 'event 1']);
    await sub.cancel();
  });

  test('a value of a stopped native subscription never reaches the next one',
      () async {
    var starts = 0, stops = 0;
    final native = NativeStream<int>(
        onStart: (_) => starts++, onStop: () => stops++);
    final first = <int>[];
    final a = native.stream.listen(first.add);
    native.add(1); // queued by the first native subscription
    await a.cancel(); // stops it
    final second = <int>[];
    final b = native.stream.listen(second.add); // starts a new one
    native.add(2);
    await Future<void>.delayed(Duration.zero);
    expect((starts, stops), (2, 1));
    expect(first, isEmpty);
    expect(second, [2]);
    await b.cancel();
  });

  test('the initial value goes to the first listener only', () async {
    final native = NativeStream<int>(
        onStart: (_) {}, onStop: () {}, initialValue: () => 7);
    final first = <int>[];
    final second = <int>[];
    final a = native.stream.listen(first.add);
    await Future<void>.delayed(Duration.zero);
    final b = native.stream.listen(second.add);
    await Future<void>.delayed(Duration.zero);
    expect(first, [7]);
    expect(second, isEmpty);
    await a.cancel();
    await b.cancel();
  });

  test('nothing is delivered after the native subscription stopped', () async {
    final native = NativeStream<int>(onStart: (_) {}, onStop: () {});
    final seen = <int>[];
    final sub = native.stream.listen(seen.add);
    native.add(1);
    await sub.cancel();
    native.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(seen, isEmpty);
  });

  test('errors are delivered asynchronously too', () async {
    final native = NativeStream<int>(onStart: (_) {}, onStop: () {});
    final errors = <Object>[];
    final sub = native.stream.listen((_) {}, onError: errors.add);
    native.addError(StateError('x'));
    expect(errors, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<StateError>());
    await sub.cancel();
  });
}
