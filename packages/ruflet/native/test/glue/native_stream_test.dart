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
