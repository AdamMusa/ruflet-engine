// Release discipline for JNI references (SPEC §4.3 T4).
//
// Every JObject is a global reference. High-rate callbacks (sensors, camera
// frames) would exhaust the global reference table if they waited for
// finalizers, so callback arguments and temporaries are released explicitly.
import 'package:jni/jni.dart';

/// Runs [body] with [object], then releases [object] (also when [body]
/// throws). Null passes through.
R withReleased<T extends JObject?, R>(T object, R Function(T object) body) {
  try {
    return body(object);
  } finally {
    if (object != null && !object.isReleased) object.release();
  }
}

/// A Dart string from a JString, releasing the JString; null for null.
String? takeString(JString? value) =>
    value?.toDartString(releaseOriginal: true);

/// Dart strings from a `String[]`, releasing the array and its elements.
List<String?> takeStrings(JArray<JString?>? array) {
  if (array == null) return const [];
  try {
    return [
      for (var i = 0; i < array.length; i++) takeString(array[i]),
    ];
  } finally {
    array.release();
  }
}

/// Dart ints from an `int[]`, releasing the array.
List<int> takeInts(JIntArray? array) {
  if (array == null) return const [];
  try {
    return array.getRange(0, array.length).toList();
  } finally {
    array.release();
  }
}
