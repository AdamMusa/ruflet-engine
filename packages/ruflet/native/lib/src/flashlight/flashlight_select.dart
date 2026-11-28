// Web has no dart:ffi: it gets the stub, which is never called there (the
// glue answers "supported only on Android and iOS devices" off mobile).
export 'flashlight_stub.dart' if (dart.library.ffi) 'flashlight_native.dart';
