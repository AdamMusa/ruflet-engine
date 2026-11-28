// Blocks that Apple may call at any time, on any thread, including the main
// thread from its run loop (outside any Dart task).
//
// Wave-0 spikes (Flutter 3.41.2 / Dart 3.11, iOS simulator; Dart 3.11-3.13
// on macOS JIT and AOT):
// - S8: an isolate-local callback (Pointer.fromFunction block,
//   NativeCallable.isolateLocal IMP or C function) that the main run loop
//   calls outside a Dart task aborts the process ("isolate=(nil)" in
//   DLRT_GetFfiCallbackMetadata): merged threads do not keep the root
//   isolate entered between tasks. blocks.dart and delegates.dart are
//   therefore only for callbacks made synchronously during a Dart call.
// - S1: NativeCallable.isolateGroupBound works from any thread, but only if
//   the callback calls no Dart callback itself (calling a
//   NativeCallable.listener from it aborts in
//   OSThread::EnableThreadInterrupts). Retaining the arguments with leaf FFI
//   calls and posting them with NativeApi.postCObject works, JIT and AOT.
//
// So an AsyncBlock's invoke function is one isolateGroupBound trampoline per
// C signature. It retains every object argument and posts the addresses to
// the block's port (stored in the block's target field); the Dart closure
// runs on the root isolate's event loop, after the native caller returned,
// and the objects are released after it. These blocks return nothing.
// NativeCallable.isolateGroupBound is experimental (owner question Q4).
//
// The trampolines may touch no isolate-local state: only their arguments,
// @Native externals and leaf calls.
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:objective_c/objective_c.dart' as objc;

import 'msg.dart';

@Native<Pointer<Void> Function(Pointer<Void>)>(symbol: 'objc_retain', isLeaf: true)
external Pointer<Void> _retain(Pointer<Void> object);

@Native<Void Function(Pointer<Void>)>(symbol: 'objc_release', isLeaf: true)
external void _releaseLeaf(Pointer<Void> object);

@Native<Pointer<Void> Function(Size)>(symbol: 'malloc', isLeaf: true)
external Pointer<Void> _malloc(int size);

@Native<Void Function(Pointer<Void>)>(symbol: 'free', isLeaf: true)
external void _free(Pointer<Void> pointer);

// Dart_CObject (dart_native_api.h): a 4-byte type, then an 8-byte aligned
// union; kArray holds (intptr_t length, Dart_CObject** values).
const _kNull = 0;
const _kInt64 = 3;
const _kArray = 6;
const _cObjectSize = 48;

final class _CObject extends Struct {
  @Int32()
  external int type;
  @Int32()
  external int padding;
  @Int64()
  external int first; // as_int64, or as_array.length
  @IntPtr()
  external int second; // as_array.values
}

typedef _Block = Pointer<objc.ObjCBlockImpl>;

/// Posts [values] (already retained object addresses) to [port]; releases
/// them again when the port is closed.
void _post(int port, List<int> values) {
  final root = _malloc(_cObjectSize * (values.length + 1) + 8 * values.length)
      .cast<_CObject>();
  final elements = Pointer<_CObject>.fromAddress(root.address + _cObjectSize);
  final slots = Pointer<IntPtr>.fromAddress(
      root.address + _cObjectSize * (values.length + 1));
  root.ref
    ..type = values.isEmpty ? _kNull : _kArray
    ..first = values.length
    ..second = slots.address;
  for (var i = 0; i < values.length; i++) {
    final element =
        Pointer<_CObject>.fromAddress(elements.address + i * _cObjectSize);
    element.ref
      ..type = _kInt64
      ..first = values[i];
    slots[i] = element.address;
  }
  final posted = NativeApi.postCObject
      .cast<NativeFunction<Bool Function(Int64, Pointer<_CObject>)>>()
      .asFunction<bool Function(int, Pointer<_CObject>)>(isLeaf: true)(
          port, root);
  _free(root.cast());
  if (!posted) {
    for (final value in values) {
      if (value != 0) _releaseLeaf(Pointer.fromAddress(value));
    }
  }
}

int _keep(Pointer<Void> object) =>
    object == nullptr ? 0 : _retain(object).address;

void _invokeV(_Block block) => _post(block.ref.target.address, const []);
void _invokeO(_Block block, Pointer<Void> a) =>
    _post(block.ref.target.address, [_keep(a)]);
void _invokeOO(_Block block, Pointer<Void> a, Pointer<Void> b) =>
    _post(block.ref.target.address, [_keep(a), _keep(b)]);
void _invokeB(_Block block, bool a) =>
    _post(block.ref.target.address, [a ? 1 : 0]);
void _invokeBO(_Block block, bool a, Pointer<Void> b) =>
    _post(block.ref.target.address, [a ? 1 : 0, _keep(b)]);

final _trampolineV =
    NativeCallable<Void Function(_Block)>.isolateGroupBound(_invokeV);
final _trampolineO =
    NativeCallable<Void Function(_Block, Pointer<Void>)>.isolateGroupBound(
        _invokeO);
final _trampolineOO = NativeCallable<
    Void Function(_Block, Pointer<Void>, Pointer<Void>)>.isolateGroupBound(
    _invokeOO);
final _trampolineB =
    NativeCallable<Void Function(_Block, Bool)>.isolateGroupBound(_invokeB);
final _trampolineBO =
    NativeCallable<Void Function(_Block, Bool, Pointer<Void>)>.isolateGroupBound(
        _invokeBO);

void _report(Object error, StackTrace stack) =>
    FlutterError.reportError(FlutterErrorDetails(
        exception: error, stack: stack, library: 'ruflet_native'));

/// A block whose Dart closure runs later on the root isolate's event loop,
/// whenever and on whichever thread Apple calls it.
///
/// Object arguments arrive retained and are released after the closure
/// returns: use them inside the closure, or retain them. Keep the AsyncBlock
/// until native code can no longer call it, then [close] it.
class AsyncBlock {
  AsyncBlock._(NativeCallable trampoline, int arity, this._isObject,
      void Function(List<int> values) onValues)
      : _arity = arity {
    _port = RawReceivePort((Object? message) {
      final values = message == null ? const <int>[] : (message as List).cast<int>();
      try {
        onValues(values);
      } catch (error, stack) {
        _report(error, stack);
      } finally {
        for (var i = 0; i < values.length; i++) {
          if (_isObject[i] && values[i] != 0) {
            release(Pointer.fromAddress(values[i]));
          }
        }
      }
    }, 'ruflet_native AsyncBlock');
    block = objc.ObjCBlockBase(
        objc.newPointerBlock(trampoline.nativeFunction.cast(),
            Pointer.fromAddress(_port.sendPort.nativePort)),
        retain: false,
        release: true);
  }

  // ignore: unused_field
  final int _arity;
  final List<bool> _isObject;
  late final RawReceivePort _port;

  /// The block to hand to Apple (`block.ref.pointer`).
  late final objc.ObjCBlockBase block;

  /// The raw block pointer.
  Obj get pointer => block.ref.pointer.cast();

  /// `void (^)(void)`
  factory AsyncBlock.voidCallback(void Function() fn) =>
      AsyncBlock._(_trampolineV, 0, const [], (_) => fn());

  /// `void (^)(id)`
  factory AsyncBlock.obj(void Function(Obj a) fn) => AsyncBlock._(
      _trampolineO, 1, const [true], (v) => fn(Pointer.fromAddress(v[0])));

  /// `void (^)(id, id)`
  factory AsyncBlock.objObj(void Function(Obj a, Obj b) fn) => AsyncBlock._(
      _trampolineOO,
      2,
      const [true, true],
      (v) => fn(Pointer.fromAddress(v[0]), Pointer.fromAddress(v[1])));

  /// `void (^)(BOOL)`
  factory AsyncBlock.boolean(void Function(bool a) fn) =>
      AsyncBlock._(_trampolineB, 1, const [false], (v) => fn(v[0] != 0));

  /// `void (^)(BOOL, id)`
  factory AsyncBlock.boolObj(void Function(bool a, Obj b) fn) => AsyncBlock._(
      _trampolineBO,
      2,
      const [false, true],
      (v) => fn(v[0] != 0, Pointer.fromAddress(v[1])));

  bool _closed = false;

  /// Stops delivery and drops this side's block reference. Calls that
  /// arrive afterwards are dropped (their objects released natively).
  void close() {
    if (_closed) return;
    _closed = true;
    _port.close();
    block.ref.release();
  }
}
