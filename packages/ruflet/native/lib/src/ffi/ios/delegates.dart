// Delegate and protocol objects whose methods are Dart functions.
//
// objective_c's ObjCProtocolBuilder passes the "trampoline" straight to
// class_addMethod as the method's IMP (objective_c src/protocol.m), so a
// NativeCallable.isolateLocal taking (self, _cmd, args...) is the method
// itself, with no native trampoline. Each builder makes its own class, so
// each delegate object has its own Dart closures.
//
// An isolateLocal callable aborts the process unless the root isolate is
// entered on the calling thread: it may only be called synchronously inside
// a Dart call into native code. Spike S8 showed that UIKit calling such an
// IMP later from the main run loop (a timer, a picker's delegate callback)
// aborts on Flutter 3.41.2, so asynchronous delegate methods need another
// mechanism (owner question Q4; see async_blocks.dart). Each construction
// site names its guarantee (SPEC §4.2).
//
// Most UIKit delegate properties are weak: the owner keeps a strong
// reference to [DartDelegate.object] for as long as the operation runs, and
// calls [DartDelegate.close] only once no native code can call it any more.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:objective_c/objective_c.dart' as objc;

import 'blocks.dart';
import 'msg.dart';

typedef _Imp0 = Void Function(Obj, Sel);
typedef _Imp1 = Void Function(Obj, Sel, Obj);
typedef _Imp2 = Void Function(Obj, Sel, Obj, Obj);
typedef _Imp3 = Void Function(Obj, Sel, Obj, Obj, Obj);
typedef _ImpBool1 = Bool Function(Obj, Sel, Obj);
typedef _ImpObj1 = Obj Function(Obj, Sel, Obj);
typedef _ImpObj2 = Obj Function(Obj, Sel, Obj, Obj);

void _report(Object error, StackTrace stack) =>
    FlutterError.reportError(FlutterErrorDetails(
        exception: error, stack: stack, library: 'ruflet_native'));

final objc.ObjCBlockBase _unusedBlock = MainThreadBlock.voidCallback(() {});

/// Builds one Objective-C object whose methods run Dart closures.
class DartDelegate {
  DartDelegate(String debugName)
      : _builder = objc.ObjCProtocolBuilder(debugName: 'RufletNative$debugName');

  final objc.ObjCProtocolBuilder _builder;
  final List<NativeCallable> _callables = [];
  objc.NSObject? _object;
  bool _closed = false;

  /// Declares conformance to the protocol [name] (for APIs that check
  /// `conformsToProtocol:`); `respondsToSelector:` works for every method.
  void conformTo(String name) {
    final protocol = objc.getProtocol(name);
    _builder.addProtocol(objc.Protocol.fromPointer(protocol.cast()));
  }

  /// Adds [selector] with the Objective-C type encoding [types], implemented
  /// by [callable], which receives `(self, _cmd, args...)`.
  void implement(String selector, String types, NativeCallable callable) {
    if (_object != null) throw StateError('DartDelegate is already built');
    // class_addMethod keeps the type string; the class lives as long as the
    // process, so the string is never freed.
    final signature = types.toNativeUtf8().cast<Char>();
    _builder.implementMethod(
        sel(selector), signature, callable.nativeFunction.cast(), _unusedBlock);
    _callables.add(callable);
  }

  /// `- (void)selector`
  void onVoid(String selector, void Function(Obj self) fn) => implement(
      selector,
      'v@:',
      NativeCallable<_Imp0>.isolateLocal((Obj s, Sel _) {
        try {
          fn(s);
        } catch (e, st) {
          _report(e, st);
        }
      }));

  /// `- (void)selector:(id)a`
  void onVoid1(String selector, void Function(Obj self, Obj a) fn) =>
      implement(
          selector,
          'v@:@',
          NativeCallable<_Imp1>.isolateLocal((Obj s, Sel _, Obj a) {
            try {
              fn(s, a);
            } catch (e, st) {
              _report(e, st);
            }
          }));

  /// `- (void)selector:(id)a b:(id)b`
  void onVoid2(String selector, void Function(Obj self, Obj a, Obj b) fn) =>
      implement(
          selector,
          'v@:@@',
          NativeCallable<_Imp2>.isolateLocal((Obj s, Sel _, Obj a, Obj b) {
            try {
              fn(s, a, b);
            } catch (e, st) {
              _report(e, st);
            }
          }));

  /// `- (void)selector:(id)a b:(id)b c:(id)c`
  void onVoid3(
          String selector, void Function(Obj self, Obj a, Obj b, Obj c) fn) =>
      implement(
          selector,
          'v@:@@@',
          NativeCallable<_Imp3>.isolateLocal(
              (Obj s, Sel _, Obj a, Obj b, Obj c) {
            try {
              fn(s, a, b, c);
            } catch (e, st) {
              _report(e, st);
            }
          }));

  /// `- (BOOL)selector:(id)a`; an exception answers NO.
  void onBool1(String selector, bool Function(Obj self, Obj a) fn) =>
      implement(
          selector,
          'B@:@',
          NativeCallable<_ImpBool1>.isolateLocal((Obj s, Sel _, Obj a) {
            try {
              return fn(s, a);
            } catch (e, st) {
              _report(e, st);
              return false;
            }
          }, exceptionalReturn: false));

  /// `- (id)selector:(id)a`; an exception answers nil. The returned object
  /// must stay alive after the call (autoreleased or owned elsewhere).
  void onObj1(String selector, Obj Function(Obj self, Obj a) fn) => implement(
      selector,
      '@@:@',
      NativeCallable<_ImpObj1>.isolateLocal((Obj s, Sel _, Obj a) {
        try {
          return fn(s, a);
        } catch (e, st) {
          _report(e, st);
          return nil;
        }
      }));

  /// `- (id)selector:(id)a b:(id)b`; an exception answers nil.
  void onObj2(String selector, Obj Function(Obj self, Obj a, Obj b) fn) =>
      implement(
          selector,
          '@@:@@',
          NativeCallable<_ImpObj2>.isolateLocal((Obj s, Sel _, Obj a, Obj b) {
            try {
              return fn(s, a, b);
            } catch (e, st) {
              _report(e, st);
              return nil;
            }
          }));

  /// The delegate object (built on first use). Keep a strong reference while
  /// native code may call it.
  objc.NSObject get object {
    if (_closed) throw StateError('DartDelegate is closed');
    return _object ??= _builder.build(keepIsolateAlive: false);
  }

  /// The raw object pointer of [object].
  Obj get pointer => object.ref.pointer;

  /// Closes the Dart callables and drops the object. Call only after the
  /// native side can no longer call any method (delegate cleared, operation
  /// finished).
  void close() {
    if (_closed) return;
    _closed = true;
    for (final callable in _callables) {
      callable.close();
    }
    _callables.clear();
    _object = null;
  }
}
