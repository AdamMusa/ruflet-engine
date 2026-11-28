// Typed objc_msgSend calls, cast once from package:objective_c's
// msgSendPointer and cached per C signature.
//
// A raw pointer returned by a getter is usually autoreleased: use it
// synchronously, inside the current run-loop turn (or an autorelease pool),
// or retain it. Methods that return +1 objects (alloc/init, new, copy) need
// an explicit release.
import 'dart:ffi';

import 'package:ffi/ffi.dart' show calloc;
import 'package:objective_c/objective_c.dart' as objc;

/// An Objective-C object pointer (`id`).
typedef Obj = Pointer<objc.ObjCObjectImpl>;

/// An Objective-C selector (`SEL`).
typedef Sel = Pointer<objc.ObjCSelector>;

/// `nil`.
final Obj nil = nullptr;

final Map<String, Sel> _selectors = {};

/// The selector named [name], registered once.
Sel sel(String name) => _selectors[name] ??= objc.registerName(name);

final Map<String, Obj> _classes = {};

/// The class named [name] (its framework must be loaded first, see
/// frameworks.dart), or throws objective_c's FailedToLoadClassException.
Obj cls(String name) => _classes[name] ??= objc.getClass(name);

/// The class named [name], or null when no loaded image defines it.
Obj? clsOrNull(String name) {
  final cached = _classes[name];
  if (cached != null) return cached;
  try {
    return _classes[name] = objc.getClass(name);
  } on objc.FailedToLoadClassException {
    return null;
  }
}

// id (id, SEL, ...)
final Obj Function(Obj, Sel) msgObj = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel)>>()
    .asFunction();
final Obj Function(Obj, Sel, Obj) msgObjObj = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, Obj)>>()
    .asFunction();
final Obj Function(Obj, Sel, Obj, Obj) msgObjObjObj = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, Obj, Obj)>>()
    .asFunction();
final Obj Function(Obj, Sel, Obj, Obj, Obj, Obj) msgObj4Obj = objc
    .msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, Obj, Obj, Obj, Obj)>>()
    .asFunction();
final Obj Function(Obj, Sel, int) msgObjLong = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, Long)>>()
    .asFunction();
final Obj Function(Obj, Sel, int) msgObjULong = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, UnsignedLong)>>()
    .asFunction();
final Obj Function(Obj, Sel, Pointer<Obj>) msgObjErr = objc.msgSendPointer
    .cast<NativeFunction<Obj Function(Obj, Sel, Pointer<Obj>)>>()
    .asFunction();

// void (id, SEL, ...)
final void Function(Obj, Sel) msgVoid = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel)>>()
    .asFunction();
final void Function(Obj, Sel, Obj) msgVoidObj = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Obj)>>()
    .asFunction();
final void Function(Obj, Sel, Obj, Obj) msgVoidObjObj = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Obj, Obj)>>()
    .asFunction();
final void Function(Obj, Sel, Obj, Obj, Obj) msgVoidObjObjObj = objc
    .msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Obj, Obj, Obj)>>()
    .asFunction();
final void Function(Obj, Sel, Obj, bool, Obj) msgVoidObjBoolObj = objc
    .msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Obj, Bool, Obj)>>()
    .asFunction();
final void Function(Obj, Sel, bool) msgVoidBool = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Bool)>>()
    .asFunction();
final void Function(Obj, Sel, bool, Obj) msgVoidBoolObj = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Bool, Obj)>>()
    .asFunction();
final void Function(Obj, Sel, int) msgVoidLong = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Long)>>()
    .asFunction();
final void Function(Obj, Sel, double) msgVoidDouble = objc.msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Double)>>()
    .asFunction();
final void Function(Obj, Sel, Sel, Obj, double) msgVoidSelObjDouble = objc
    .msgSendPointer
    .cast<NativeFunction<Void Function(Obj, Sel, Sel, Obj, Double)>>()
    .asFunction();

// BOOL (id, SEL, ...)
final bool Function(Obj, Sel) msgBool = objc.msgSendPointer
    .cast<NativeFunction<Bool Function(Obj, Sel)>>()
    .asFunction();
final bool Function(Obj, Sel, Obj) msgBoolObj = objc.msgSendPointer
    .cast<NativeFunction<Bool Function(Obj, Sel, Obj)>>()
    .asFunction();
final bool Function(Obj, Sel, Sel) msgBoolSel = objc.msgSendPointer
    .cast<NativeFunction<Bool Function(Obj, Sel, Sel)>>()
    .asFunction();
final bool Function(Obj, Sel, Pointer<Obj>) msgBoolErr = objc.msgSendPointer
    .cast<NativeFunction<Bool Function(Obj, Sel, Pointer<Obj>)>>()
    .asFunction();

// Integers (NSInteger is long, NSUInteger unsigned long on Apple's 64-bit
// ABIs).
final int Function(Obj, Sel) msgLong = objc.msgSendPointer
    .cast<NativeFunction<Long Function(Obj, Sel)>>()
    .asFunction();
final int Function(Obj, Sel) msgULong = objc.msgSendPointer
    .cast<NativeFunction<UnsignedLong Function(Obj, Sel)>>()
    .asFunction();

// Floating point: x86_64 (simulators on Intel Macs) needs the fpret variant,
// as objective_c's generated bindings do (objc.useMsgSendVariants).
final double Function(Obj, Sel) _msgDouble = objc.msgSendPointer
    .cast<NativeFunction<Double Function(Obj, Sel)>>()
    .asFunction();
final double Function(Obj, Sel) _msgDoubleFpret = objc.msgSendFpretPointer
    .cast<NativeFunction<Double Function(Obj, Sel)>>()
    .asFunction();
final double Function(Obj, Sel) _msgFloat = objc.msgSendPointer
    .cast<NativeFunction<Float Function(Obj, Sel)>>()
    .asFunction();
final double Function(Obj, Sel) _msgFloatFpret = objc.msgSendFpretPointer
    .cast<NativeFunction<Float Function(Obj, Sel)>>()
    .asFunction();

/// `double` getter (CGFloat, NSTimeInterval, ...).
double msgDouble(Obj target, Sel selector) => objc.useMsgSendVariants
    ? _msgDoubleFpret(target, selector)
    : _msgDouble(target, selector);

/// `float` getter (UIDevice.batteryLevel, ...).
double msgFloat(Obj target, Sel selector) => objc.useMsgSendVariants
    ? _msgFloatFpret(target, selector)
    : _msgFloat(target, selector);

/// CGSize / CGPoint (two CGFloats).
final class CGSize extends Struct {
  @Double()
  external double width;
  @Double()
  external double height;
}

/// CGRect.
final class CGRect extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
  @Double()
  external double width;
  @Double()
  external double height;
}

final CGRect Function(Obj, Sel) _msgRect = objc.msgSendPointer
    .cast<NativeFunction<CGRect Function(Obj, Sel)>>()
    .asFunction();
final void Function(Pointer<CGRect>, Obj, Sel) _msgRectStret = objc
    .msgSendStretPointer
    .cast<NativeFunction<Void Function(Pointer<CGRect>, Obj, Sel)>>()
    .asFunction();

/// A CGRect getter (UIScreen.bounds, ...). Structs larger than 16 bytes are
/// returned through objc_msgSend_stret on x86_64.
({double x, double y, double width, double height}) msgRect(
    Obj target, Sel selector) {
  if (!objc.useMsgSendVariants) {
    final r = _msgRect(target, selector);
    return (x: r.x, y: r.y, width: r.width, height: r.height);
  }
  final buffer = calloc<CGRect>();
  try {
    _msgRectStret(buffer, target, selector);
    final r = buffer.ref;
    return (x: r.x, y: r.y, width: r.width, height: r.height);
  } finally {
    calloc.free(buffer);
  }
}

/// `[target isKindOfClass:klass]`.
bool isKindOf(Obj target, Obj klass) =>
    msgBoolObj(target, sel('isKindOfClass:'), klass);

/// `[target respondsToSelector:selector]`.
bool respondsTo(Obj target, String selector) =>
    msgBoolSel(target, sel('respondsToSelector:'), sel(selector));

/// `[target retain]`; returns [target].
Obj retain(Obj target) => objc.objectRetain(target).cast();

/// `[target release]`.
void release(Obj target) {
  if (target != nullptr) objc.objectRelease(target.cast());
}

/// A Dart string as an autoreleased NSString pointer: use it synchronously,
/// on the main thread or inside `objc.autoReleasePool`.
Obj nsString(String value) => value.toNSString().ref.retainAndAutorelease();

/// An NSString pointer as a Dart string; null for nil.
String? dartString(Obj value) => value == nullptr
    ? null
    : objc.NSString.fromPointer(value, retain: true, release: true)
        .toDartString();
