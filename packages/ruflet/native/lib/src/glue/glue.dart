// What a feature's service glue may import besides package:ruflet/ruflet.dart:
// never package:ruflet/src/... (SPEC §3.3).
export 'package:ruflet/ruflet.dart'
    show invokeArgs, requireInvokeArg, isMobilePlatform, isAndroidMobile, isIOSMobile;

export 'errors.dart';
export 'native_stream.dart';
export 'platform.dart' show isNativeTarget;
