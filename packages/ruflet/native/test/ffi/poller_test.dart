// The Android shared layer's Poller (plain Dart: it reads through a
// callback, so it runs on any host).
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_native/src/ffi/android/poller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var reads = 0;
  late List<int> got;

  Poller<int> poller({bool distinctOnly = true}) => Poller<int>(
        read: () => ++reads,
        onValue: got.add,
        period: const Duration(hours: 1),
        distinctOnly: distinctOnly,
      );

  Future<void> nextTurns() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    reads = 0;
    got = [];
  });

  test('start reports the current value on a later turn, once', () async {
    final p = poller()..start();
    expect(got, isEmpty);
    await nextTurns();
    p.stop();
    expect(got, [1]);
  });

  test('stop before that turn reports nothing', () async {
    poller()
      ..start()
      ..stop();
    await nextTurns();
    expect(got, isEmpty);
    expect(reads, 0);
  });

  test('stop and start in one turn report the initial value once', () async {
    final p = poller()
      ..start()
      ..stop()
      ..start();
    await nextTurns();
    p.stop();
    expect(got, [1]);
  });

  test('a restart without emitNow drops the stopped run\'s first read',
      () async {
    final p = poller()
      ..start()
      ..stop()
      ..start(emitNow: false);
    await nextTurns();
    p.stop();
    expect(got, isEmpty);
  });

  test('poll reports changes only, unless distinctOnly is false', () async {
    var value = 7;
    final distinct = Poller<int>(
        read: () => value, onValue: got.add, period: const Duration(hours: 1))
      ..start(emitNow: false);
    distinct
      ..poll()
      ..poll();
    value = 8;
    distinct.poll();
    distinct.stop();
    expect(got, [7, 8]);

    got = [];
    final every = poller(distinctOnly: false)..start(emitNow: false);
    every
      ..poll()
      ..poll();
    every.stop();
    expect(got, hasLength(2));
  });
}
