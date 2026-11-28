import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_native/src/ffi/common/serial_worker.dart';

int _slow(int i) {
  // Later tasks are faster: a pool would finish them first.
  final until = DateTime.now().add(Duration(milliseconds: (20 - i) * 2));
  while (DateTime.now().isBefore(until)) {}
  return i;
}

void main() {
  test('tasks run one at a time, in submission order', () async {
    final worker = SerialWorker('test');
    final done = <int>[];
    await Future.wait([
      for (var i = 0; i < 20; i++) worker.run(() => _slow(i)).then(done.add)
    ]);
    await worker.close();
    expect(done, List.generate(20, (i) => i));
  });

  test('errors come back to the caller and the worker keeps going', () async {
    final worker = SerialWorker('errors');
    await expectLater(worker.run<int>(() => throw StateError('boom')),
        throwsA(isA<StateError>()));
    expect(await worker.run(() => 3), 3);
    await worker.close();
    expect(() => worker.run(() => 1), throwsStateError);
  });
}
