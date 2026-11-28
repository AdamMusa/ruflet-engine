// Java exceptions as the old plugins' texts (SPEC §3.5 E4).
import 'package:jni/jni.dart';

final Map<String, JClass> _classes = {};
final _objectToString = JClass.forName('java/lang/Object')
    .instanceMethodId('toString', '()Ljava/lang/String;');

/// The class [binaryName] (`java/lang/Exception`), looked up once.
JClass javaClass(String binaryName) =>
    _classes[binaryName] ??= JClass.forName(binaryName);

/// What Kotlin's `"$e"` printed: the object's own `toString()`.
String javaToString(JObject object) =>
    _objectToString.call(object, JString.type, []).toDartString(
        releaseOriginal: true);

/// Whether [error] is an instance of the Java class [binaryName].
bool isJavaInstance(JObject error, String binaryName) =>
    error.isInstanceOf(javaClass(binaryName));

/// The error a feature answers when its Dart code runs but its Android build
/// part (android/features/<feature>.*) is off, for example an app importing
/// an entry library without the wrapper package. Only that
/// misconfiguration produces this text.
Exception featureNotEnabled(String feature) =>
    Exception('$feature is not enabled in this Android build');

/// The class [binaryName] of a feature's Gradle dependency, or
/// [featureNotEnabled] when the dependency is not in the build.
JClass requireFeatureClass(String feature, String binaryName) {
  final cached = _classes[binaryName];
  if (cached != null) return cached;
  try {
    return _classes[binaryName] = JClass.forName(binaryName);
  } on JThrowable {
    throw featureNotEnabled(feature);
  }
}
