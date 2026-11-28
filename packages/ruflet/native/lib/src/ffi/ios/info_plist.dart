// Info.plist checks before APIs that crash without a purpose string.
import 'msg.dart';

/// Whether the app's Info.plist has [key] (for example
/// `NSMotionUsageDescription`). An API that terminates the app without its
/// purpose string checks this first and answers the old plugin's "not
/// available" error instead (SPEC §6.3).
bool hasInfoPlistKey(String key) {
  final bundle = msgObj(cls('NSBundle'), sel('mainBundle'));
  return msgObjObj(bundle, sel('objectForInfoDictionaryKey:'), nsString(key)) !=
      nil;
}

/// The Info.plist string value of [key], or null.
String? infoPlistString(String key) {
  final bundle = msgObj(cls('NSBundle'), sel('mainBundle'));
  final value =
      msgObjObj(bundle, sel('objectForInfoDictionaryKey:'), nsString(key));
  if (value == nil || !isKindOf(value, cls('NSString'))) return null;
  return dartString(value);
}
