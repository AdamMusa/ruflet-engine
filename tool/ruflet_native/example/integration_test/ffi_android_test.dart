// The shared Android layer on the device (SPEC §4.1, spikes S7/S4): the
// main thread, the single ActivityBinding proxy (attach, plugin-class
// uniqueness, re-registration as after a hot restart, activity and
// permission results, lifecycle), the poller and the serial worker.
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jni/jni.dart';
import 'package:ruflet_native/src/ffi/android/activity_binding.dart';
import 'package:ruflet_native/src/ffi/android/bindings/shared.g.dart';
import 'package:ruflet_native/src/ffi/android/java_errors.dart';
import 'package:ruflet_native/src/ffi/android/jni_env.dart';
import 'package:ruflet_native/src/ffi/android/main_thread.dart';
import 'package:ruflet_native/src/ffi/android/poller.dart';
import 'package:ruflet_native/src/ffi/android/serial_worker.dart';

const _resultCanceled = 0; // Activity.RESULT_CANCELED
const _permissionDenied = -1; // PackageManager.PERMISSION_DENIED

int _sdkInWorker() => Build$VERSION.SDK_INT;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = Platform.isAndroid ? null : 'Android only';

  group('Android shared layer', skip: skip, () {
    testWidgets('Dart runs on the main thread (merged threads)', (t) async {
      expect(isMainThread(), isTrue);
      assertMainThread('test');
      expect(sdkInt, greaterThanOrEqualTo(24));
      expect(applicationContext.packageName!.toDartString(releaseOriginal: true),
          'dev.ruflet.ruflet_native_example');
    });

    testWidgets('main Handler and Executor run Dart Runnables on main',
        (t) async {
      final order = <String>[];
      final posted = Completer<void>();
      final task = postToMain(() {
        order.add('posted:${isMainThread()}');
        posted.complete();
      });
      order.add('after post');
      await posted.future.timeout(const Duration(seconds: 5));
      task.release();
      expect(order, ['after post', 'posted:true']);

      final executed = Completer<bool>();
      final r = runnable(() => executed.complete(isMainThread()));
      mainExecutor.execute(r);
      expect(await executed.future.timeout(const Duration(seconds: 5)), isTrue);
      r.release();

      final delayed = Completer<void>();
      final watch = Stopwatch()..start();
      postToMain(delayed.complete, delay: const Duration(milliseconds: 200));
      await delayed.future.timeout(const Duration(seconds: 5));
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(150));
    });

    testWidgets('S7: the one proxy attaches through engineForId', (t) async {
      final binding = ActivityBinding.instance;
      expect(binding.attached.value, isTrue);
      expect(binding.attachCount, greaterThanOrEqualTo(1));
      final engine = FlutterEngine.engineForId(engineId)!;
      final plugins = engine.plugins;
      final proxyClass = binding.debugProxyClass;
      expect(plugins.has(proxyClass), isTrue);
      // jni_flutter's own plugin is still registered beside ours.
      final jniFlutter =
          JClass.forName('com/github/dart_lang/jni_flutter/JniFlutterPlugin');
      expect(plugins.has(jniFlutter), isTrue);
      releaseAll([proxyClass, jniFlutter, plugins, engine]);
    });

    testWidgets('S7: re-registration replaces the previous proxy', (t) async {
      final old = ActivityBinding.instance;
      final fresh = ActivityBinding.debugReregister();
      expect(identical(old, fresh), isFalse);
      expect(fresh.replacedPreviousProxy, isTrue);
      expect(fresh.attached.value, isTrue);
      expect(old.attached.value, isFalse);
      final engine = FlutterEngine.engineForId(engineId)!;
      final plugins = engine.plugins;
      final proxyClass = fresh.debugProxyClass;
      expect(plugins.has(proxyClass), isTrue);
      releaseAll([proxyClass, plugins, engine]);
    });

    testWidgets('activity results and lifecycle reach the proxy', (t) async {
      final binding = ActivityBinding.instance;
      final events = <ActivityLifecycleEvent>[];
      final sub = binding.lifecycle.listen(events.add);
      final callsBefore = binding.activityResultCalls;
      // The system document picker (file_picker's path) runs in this task,
      // so finishActivity can cancel it.
      final intent = using((arena) {
        final i = Intent.new$3(
            'android.intent.action.GET_CONTENT'.toJString()..releasedBy(arena));
        i.setType('*/*'.toJString()..releasedBy(arena))?.release();
        i.addCategory('android.intent.category.OPENABLE'.toJString()
              ..releasedBy(arena))
            ?.release();
        return i;
      });
      final result = binding.startActivityForResult(
          intent, (resultCode, data) => resultCode);
      intent.release();
      // Cancel the started activity programmatically, as the picker tests
      // will (SPEC §8.3).
      await Future<void>.delayed(const Duration(seconds: 2));
      final requestCode = binding.lastRequestCode!;
      withActivity((activity) => activity.finishActivity(requestCode));
      final code = await result.timeout(const Duration(seconds: 10),
          onTimeout: () => -999);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await sub.cancel();
      expect(code, _resultCanceled);
      expect(binding.activityResultCalls, callsBefore + 1);
      expect(events, containsAllInOrder(
          [ActivityLifecycleEvent.paused, ActivityLifecycleEvent.resumed]));
    });

    testWidgets('permission results reach the proxy', (t) async {
      // A permission the example's manifest does not declare: Android answers
      // DENIED at once, without a dialog.
      final grants = await ActivityBinding.instance
          .requestPermissions(['android.permission.READ_CALENDAR'])
          .timeout(const Duration(seconds: 10));
      expect(grants, [_permissionDenied]);
    });

    testWidgets('Java errors and the feature-off text', (t) async {
      Object? error;
      try {
        JClass.forName('does/not/Exist');
      } on JThrowable catch (e) {
        error = e;
        expect(javaToString(e), contains('does'));
      }
      expect(error, isNotNull);
      expect(
          () => requireFeatureClass('camera', 'androidx/camera/core/Missing'),
          throwsA(predicate((e) =>
              e.toString() ==
              'Exception: camera is not enabled in this Android build')));
    });

    testWidgets('the poller reports the first value and changes', (t) async {
      var value = 1;
      final seen = <int>[];
      final poller = Poller<int>(
          read: () => value,
          onValue: seen.add,
          period: const Duration(milliseconds: 100))
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      value = 2;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      poller.stop();
      expect(seen, [1, 2]);
    });

    testWidgets('the serial worker runs JNI work in order', (t) async {
      final worker = AndroidSerialWorker('test');
      final done = <int>[];
      final futures = [
        for (var i = 0; i < 20; i++)
          worker.run(() {
            // Blocking work in the helper isolate, over JNI.
            final sdk = _sdkInWorker();
            return i * 1000 + (sdk > 0 ? 1 : 0);
          }).then((v) => done.add(v ~/ 1000))
      ];
      await Future.wait(futures);
      await worker.close();
      expect(done, List.generate(20, (i) => i));
    });
  });
}
