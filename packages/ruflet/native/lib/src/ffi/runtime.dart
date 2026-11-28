// The platform-neutral entry into the shared FFI layer. Web gets stub.dart
// only and never imports dart:ffi.
export 'stub.dart' if (dart.library.ffi) 'native.dart' show ensureNativeRuntime;
