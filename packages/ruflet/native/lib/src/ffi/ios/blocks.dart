// Objective-C blocks that run Dart closures, built in Dart alone.
//
// This is what ffigen's `fromFunction` blocks do, without the generated .m
// file: objective_c's newClosureBlock with a static Pointer.fromFunction
// trampoline per C signature. Such a trampoline may only run while the root
// isolate is entered on its thread, that is synchronously inside a Dart call
// into native code (for example enumerateObjectsUsingBlock:, or a callback
// an API makes before it returns). Spike S8 showed that a block the main run
// loop calls later, outside any Dart task, aborts the process on Flutter
// 3.41.2: use AsyncBlock (async_blocks.dart) for those. Every construction
// site names its guarantee in a comment (SPEC §4.2).
//
// This file and delegates.dart are the only users of objective_c's
// ffigen-support helpers, so an objective_c version bump touches two files.
import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:objective_c/objective_c.dart' as objc;

import 'msg.dart';

typedef _Block = Pointer<objc.ObjCBlockImpl>;

void _guard(void Function() body) {
  try {
    body();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
        exception: error, stack: stack, library: 'ruflet_native'));
  }
}

void _v(_Block b) => _guard(() => (objc.getBlockClosure(b) as void Function())());
void _o(_Block b, Obj a) =>
    _guard(() => (objc.getBlockClosure(b) as void Function(Obj))(a));
void _oo(_Block b, Obj a, Obj c) =>
    _guard(() => (objc.getBlockClosure(b) as void Function(Obj, Obj))(a, c));
void _b(_Block b, bool a) =>
    _guard(() => (objc.getBlockClosure(b) as void Function(bool))(a));
void _bo(_Block b, bool a, Obj c) =>
    _guard(() => (objc.getBlockClosure(b) as void Function(bool, Obj))(a, c));
void _obo(_Block b, Obj a, bool c, Obj d) => _guard(
    () => (objc.getBlockClosure(b) as void Function(Obj, bool, Obj))(a, c, d));

final _vPtr = Pointer.fromFunction<Void Function(_Block)>(_v);
final _oPtr = Pointer.fromFunction<Void Function(_Block, Obj)>(_o);
final _ooPtr = Pointer.fromFunction<Void Function(_Block, Obj, Obj)>(_oo);
final _bPtr = Pointer.fromFunction<Void Function(_Block, Bool)>(_b);
final _boPtr = Pointer.fromFunction<Void Function(_Block, Bool, Obj)>(_bo);
final _oboPtr =
    Pointer.fromFunction<Void Function(_Block, Obj, Bool, Obj)>(_obo);

objc.ObjCBlockBase _block(Pointer<NativeFunction> invoke, Function fn) =>
    objc.ObjCBlockBase(objc.newClosureBlock(invoke.cast(), fn, true),
        retain: false, release: true);

/// Blocks whose Dart closure runs inline on the main thread.
///
/// The returned block is owned by the caller (released when it is garbage
/// collected, or with `block.ref.release()`); APIs that keep a block copy it.
/// Object arguments are borrowed for the call only: copy what you need or
/// retain them before the closure returns.
abstract final class MainThreadBlock {
  /// `void (^)(void)`
  static objc.ObjCBlockBase voidCallback(void Function() fn) =>
      _block(_vPtr, fn);

  /// `void (^)(id)`
  static objc.ObjCBlockBase obj(void Function(Obj a) fn) => _block(_oPtr, fn);

  /// `void (^)(id, id)`
  static objc.ObjCBlockBase objObj(void Function(Obj a, Obj b) fn) =>
      _block(_ooPtr, fn);

  /// `void (^)(BOOL)`
  static objc.ObjCBlockBase boolean(void Function(bool a) fn) =>
      _block(_bPtr, fn);

  /// `void (^)(BOOL, id)`
  static objc.ObjCBlockBase boolObj(void Function(bool a, Obj b) fn) =>
      _block(_boPtr, fn);

  /// `void (^)(id, BOOL, id)`
  static objc.ObjCBlockBase objBoolObj(
          void Function(Obj a, bool b, Obj c) fn) =>
      _block(_oboPtr, fn);
}
