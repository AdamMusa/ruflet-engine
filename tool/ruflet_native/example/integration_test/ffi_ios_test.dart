// The shared iOS layer on the device (SPEC §4.2, spikes S8 and S1):
// synchronous Dart-IMP delegates, AsyncBlocks called by Foundation and UIKit
// from the main run loop and from background threads, notifications, view
// controllers, the Info.plist guard, libSystem/dispatch and the serial
// worker. (Spike S8 showed that isolate-local callbacks called from the run
// loop abort; those cases live in the spike notes, not here.)
import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objective_c/objective_c.dart' as objc;
import 'package:ruflet_native/src/ffi/ios/async_blocks.dart';
import 'package:ruflet_native/src/ffi/ios/c/dispatch.dart';
import 'package:ruflet_native/src/ffi/ios/c/libsystem.dart';
import 'package:ruflet_native/src/ffi/ios/delegates.dart';
import 'package:ruflet_native/src/ffi/ios/frameworks.dart';
import 'package:ruflet_native/src/ffi/ios/info_plist.dart';
import 'package:ruflet_native/src/ffi/ios/main_queue.dart';
import 'package:ruflet_native/src/ffi/ios/msg.dart';
import 'package:ruflet_native/src/ffi/ios/notifications.dart';
import 'package:ruflet_native/src/ffi/ios/serial_worker.dart';
import 'package:ruflet_native/src/ffi/ios/ui.dart';

const _timeout = Duration(seconds: 10);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final skip = Platform.isIOS ? null : 'iOS only';

  group('iOS shared layer', skip: skip, () {
    testWidgets('Dart runs on the main thread (merged threads)', (t) async {
      expect(isMainThread(), isTrue);
      assertMainThread('test');
    });

    testWidgets('delegate methods dispatch per instance and conform', (t) async {
      final calls = <String>[];
      DartDelegate make(String tag) => DartDelegate('Per$tag')
        ..conformTo('NSObject')
        ..onVoid1('ping:', (self, arg) => calls.add(tag))
        ..onBool1('answer:', (self, arg) => tag == 'b');
      final a = make('a');
      final b = make('b');
      msgVoidObj(a.pointer, sel('ping:'), nil);
      msgVoidObj(b.pointer, sel('ping:'), nil);
      expect(calls, ['a', 'b']);
      expect(msgBoolObj(a.pointer, sel('answer:'), nil), isFalse);
      expect(msgBoolObj(b.pointer, sel('answer:'), nil), isTrue);
      expect(
          msgBoolObj(a.pointer, sel('conformsToProtocol:'),
              objc.getProtocol('NSObject').cast()),
          isTrue);
      a.close();
      b.close();
    });

    testWidgets('top view controller, present and dismiss', (t) async {
      expect(keyWindow(), isNotNull);
      final top = topViewController()!;
      final controller = msgObj(msgObj(cls('UIViewController'), sel('alloc')),
          sel('init'));
      final presented = Completer<void>();
      presentViewController(top, controller,
          animated: false, completion: presented.complete);
      await presented.future.timeout(_timeout);
      expect(topViewController(), controller);
      final dismissed = Completer<void>();
      dismissViewController(controller,
          animated: false, completion: dismissed.complete);
      await dismissed.future.timeout(_timeout);
      expect(topViewController(), top);
      release(controller);
    });

    testWidgets('the Info.plist guard', (t) async {
      expect(hasInfoPlistKey('NSCameraUsageDescription'), isTrue);
      expect(hasInfoPlistKey('NSMotionUsageDescription'), isFalse);
      expect(infoPlistString('CFBundleIdentifier'),
          'dev.ruflet.rufletNativeExample');
    });

    testWidgets('frameworks open lazily', (t) async {
      final motion = Frameworks.classIn('CoreMotion', 'CMMotionManager');
      expect(motion, isNot(nil));
      expect(Frameworks.isOpen('CoreMotion'), isTrue);
      final videoType = Frameworks.constant('AVFoundation', 'AVMediaTypeVideo');
      expect(dartString(videoType), 'vide');
    });

    testWidgets('libSystem and dispatch', (t) async {
      expect(sysctlString('hw.machine'), isNotEmpty);
      expect(sysctlInt('hw.memsize'), greaterThan(0));
      expect(uname()!.machine, isNotEmpty);
      // A listener callback from a global queue: only an int crosses.
      final got = Completer<int>();
      late final NativeCallable<DispatchFunction> listener;
      listener = NativeCallable<DispatchFunction>.listener((Pointer<Void> c) {
        got.complete(c.address);
        listener.close();
      });
      dispatchAsyncF(dispatchGetGlobalQueue(qosClassDefault, 0),
          Pointer.fromAddress(42), listener.nativeFunction);
      expect(await got.future.timeout(_timeout), 42);
    });

    testWidgets(
        'S8/S1: an AsyncBlock run by the main run loop outside a Dart task',
        (t) async {
      final ran = Completer<bool>();
      final block = AsyncBlock.voidCallback(() => ran.complete(isMainThread()));
      msgVoidObj(mainOperationQueue, sel('addOperationWithBlock:'), block.pointer);
      expect(await ran.future.timeout(_timeout), isTrue);
      block.close();
    });

    testWidgets('S1: an AsyncBlock called on a background thread with an object',
        (t) async {
      const name = 'RufletNativeBackgroundNote';
      final queue = msgObj(msgObj(cls('NSOperationQueue'), sel('alloc')), sel('init'));
      final got = Completer<String>();
      final block = AsyncBlock.obj((note) =>
          got.complete(dartString(msgObj(note, sel('name')))!));
      final center = msgObj(cls('NSNotificationCenter'), sel('defaultCenter'));
      final token = retain(msgObj4Obj(center,
          sel('addObserverForName:object:queue:usingBlock:'), nsString(name), nil,
          queue, block.pointer));
      postNotification(nsString(name));
      expect(await got.future.timeout(_timeout), name);
      msgVoidObj(center, sel('removeObserver:'), token);
      release(token);
      block.close();
      release(queue);
    });

    testWidgets('NotificationObserver delivers on a later turn', (t) async {
      const name = 'RufletNativeObserverNote';
      final seen = <String>[];
      final done = Completer<void>();
      final observer = NotificationObserver.named(name, (note) {
        seen.add(dartString(msgObj(note, sel('name')))!);
        done.complete();
      });
      postNotification(nsString(name));
      seen.add('posted');
      await done.future.timeout(_timeout);
      observer.cancel();
      expect(seen, ['posted', name]);
    });

    testWidgets('the serial worker runs Objective-C work in order', (t) async {
      final worker = IosSerialWorker('test');
      final done = <int>[];
      final futures = [
        for (var i = 0; i < 20; i++)
          worker.run(() {
            final info = msgObj(cls('NSProcessInfo'), sel('processInfo'));
            final uptime = msgDouble(info, sel('systemUptime'));
            return uptime > 0 ? i : -1;
          }).then(done.add)
      ];
      await Future.wait(futures);
      await worker.close();
      expect(done, List.generate(20, (i) => i));
    });
  });
}
