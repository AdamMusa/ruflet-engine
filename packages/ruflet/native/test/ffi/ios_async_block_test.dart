// AsyncBlock against the macOS Objective-C runtime of the host: what happens
// when Apple calls a block that the service already closed (it may keep and
// call its own copy). The iOS integration test (ffi_ios_test.dart) repeats
// this with UIKit. CI's Linux host has no Objective-C runtime.
@TestOn('mac-os')
library;

import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:objective_c/objective_c.dart' as objc;
import 'package:ruflet_native/src/ffi/ios/async_blocks.dart';
import 'package:ruflet_native/src/ffi/ios/msg.dart';

typedef _Impl = Pointer<objc.ObjCBlockImpl>;

/// The block's invoke function, which Apple calls.
Pointer<Void> _invokePointer(AsyncBlock block) =>
    block.pointer.cast<objc.ObjCBlockImpl>().ref.invoke;

void Function(_Impl) _callV(AsyncBlock block) => _invokePointer(block)
    .cast<NativeFunction<Void Function(_Impl)>>()
    .asFunction<void Function(_Impl)>();

void Function(_Impl, Pointer<Void>) _callO(AsyncBlock block) =>
    _invokePointer(block)
        .cast<NativeFunction<Void Function(_Impl, Pointer<Void>)>>()
        .asFunction<void Function(_Impl, Pointer<Void>)>();

void Function(_Impl, bool) _callB(AsyncBlock block) => _invokePointer(block)
    .cast<NativeFunction<Void Function(_Impl, Bool)>>()
    .asFunction<void Function(_Impl, bool)>();

void Function(_Impl, bool, Pointer<Void>) _callBO(AsyncBlock block) =>
    _invokePointer(block)
        .cast<NativeFunction<Void Function(_Impl, Bool, Pointer<Void>)>>()
        .asFunction<void Function(_Impl, bool, Pointer<Void>)>();

Obj _newObject() => msgObj(msgObj(cls('NSObject'), sel('alloc')), sel('init'));

int _retainCount(Obj object) => msgULong(object, sel('retainCount'));

/// Lets the port handle what is queued (the delivery or the drain).
Future<void> _turns() => Future<void>.delayed(const Duration(milliseconds: 50));

/// Apple's copy of [block], which outlives close().
_Impl _appleCopy(AsyncBlock block) =>
    objc.objectRetain(block.pointer.cast()).cast();

void _releaseAppleCopy(_Impl copy) => objc.objectRelease(copy.cast());

void main() {
  test('BOOL block: YES after close is dropped, before and after the drain',
      () async {
    final got = <bool>[];
    final block = AsyncBlock.boolean(got.add);
    final call = _callB(block);
    final copy = _appleCopy(block);
    call(copy, true);
    await _turns();
    expect(got, [true]);

    block.close();
    // close() cleared the block's port: the trampoline's post fails and it
    // must release only object slots, never the YES (objc_release((id)1)).
    call(copy, true);
    call(copy, false);
    await _turns(); // the port is closed now
    call(copy, true);
    await _turns();
    expect(got, [true]);
    expect(block.isClosed, isTrue);
    _releaseAppleCopy(copy);
  });

  test('(BOOL, id) block: the object is released, the BOOL never', () async {
    final object = _newObject();
    final baseline = _retainCount(object);
    final got = <(bool, int)>[];
    final block = AsyncBlock.boolObj(
        (ok, o) => got.add((ok, _retainCount(o) - baseline)));
    final call = _callBO(block);
    final copy = _appleCopy(block);
    call(copy, true, object.cast());
    await _turns();
    // Delivered retained once more, released after the closure.
    expect(got, [(true, 1)]);
    expect(_retainCount(object), baseline);

    call(copy, true, object.cast()); // queued before close(): drained
    block.close();
    call(copy, true, object.cast()); // after close(): the trampoline drops it
    await _turns();
    call(copy, true, object.cast()); // after the port closed
    await _turns();
    expect(got, [(true, 1)]);
    expect(_retainCount(object), baseline);
    _releaseAppleCopy(copy);
    release(object);
  });

  test('(id) block: an object queued when close() runs is released', () async {
    final object = _newObject();
    final baseline = _retainCount(object);
    var delivered = 0;
    final block = AsyncBlock.obj((_) => delivered++);
    final call = _callO(block);
    final copy = _appleCopy(block);
    call(copy, object.cast());
    block.close(); // same turn: the call is still queued
    await _turns();
    expect(delivered, 0);
    expect(_retainCount(object), baseline);
    _releaseAppleCopy(copy);
    release(object);
  });

  test('a block that closes itself from its closure', () async {
    final got = <int>[];
    late final AsyncBlock block;
    block = AsyncBlock.voidCallback(() {
      got.add(got.length);
      block.close();
    });
    final call = _callV(block);
    final copy = _appleCopy(block);
    call(copy);
    call(copy); // queued behind the first call: not delivered
    await _turns();
    call(copy);
    await _turns();
    expect(got, [0]);
    _releaseAppleCopy(copy);
  });
}
