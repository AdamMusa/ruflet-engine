// System frameworks are opened with dlopen on first use and never linked:
// an app that does not use a feature has no load command for its framework,
// and App Store scanning sees no privacy-sensitive API it does not call.
import 'dart:ffi';

import 'package:objective_c/objective_c.dart' as objc;

import 'msg.dart';

/// Lazily opened system frameworks (as ruflet-engine#136 opens AVFoundation).
abstract final class Frameworks {
  static final Map<String, DynamicLibrary> _open = {};

  /// Opens `/System/Library/Frameworks/<name>.framework/<name>` once. Opening
  /// it also registers its Objective-C classes with the runtime.
  static DynamicLibrary open(String name) => _open[name] ??=
      DynamicLibrary.open('/System/Library/Frameworks/$name.framework/$name');

  /// Whether [name] has been opened by this process (tests, tree-shaking
  /// checks).
  static bool isOpen(String name) => _open.containsKey(name);

  /// A C symbol of [framework].
  static Pointer<T> symbol<T extends NativeType>(String framework, String name) =>
      open(framework).lookup<T>(name);

  /// An exported Objective-C object constant of [framework], such as
  /// `AVMediaTypeVideo` or a notification name.
  static Obj constant(String framework, String name) =>
      symbol<objc.ObjCObjectImpl>(framework, name).cast<Obj>().value;

  /// The class [className] from [framework], opening it first.
  static Obj classIn(String framework, String className) {
    open(framework);
    return cls(className);
  }
}
