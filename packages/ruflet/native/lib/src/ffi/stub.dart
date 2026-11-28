// The FFI layer on platforms without dart:ffi (web). Nothing here runs:
// isNativeTarget is false on the web.

/// No-op off Android/iOS.
void ensureNativeRuntime() {}
