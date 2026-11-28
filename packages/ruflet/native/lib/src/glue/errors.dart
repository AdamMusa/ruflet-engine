// Error builders shared by the features (SPEC §3.5).
import 'package:flutter/services.dart';

/// What a plugin's Kotlin `result.error(code, message, details)` or Swift
/// `FlutterError(code:message:details:)` became in Dart: a
/// PlatformException with the same values, so `e.toString()` prints the
/// same `PlatformException(code, message, details, null)`. Each feature
/// keeps its codes and messages in its errors.dart with the plugin file and
/// line they come from.
PlatformException platformError(String code, String? message,
        [Object? details]) =>
    PlatformException(code: code, message: message, details: details);
