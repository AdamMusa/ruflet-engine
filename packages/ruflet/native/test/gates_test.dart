// The FFI-only rules, checked on every test run (CI also runs the scripts
// in tool/ruflet_native).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source without comments, so documentation may name what code may not use.
String _code(File file) => file
    .readAsStringSync()
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

Iterable<File> _dart(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Packages lib/ may import and pubspec.yaml may depend on (everything else
/// would be a plugin with native code, or an undeclared dependency).
const _allowedPackages = {
  'flutter', 'ruflet', 'ruflet_native', 'ffi', 'jni', 'jni_flutter',
  'objective_c', 'url_launcher_platform_interface',
  'share_plus_platform_interface', 'device_info_plus_platform_interface',
  'collection', 'cross_file', 'http', 'image', 'meta', 'mime', 'path', 'uuid',
  'plugin_platform_interface',
};

/// Imports that only FFI files may use.
final _ffiImport = RegExp(
    r'''import\s+['"](dart:ffi|package:(jni|jni_flutter|objective_c|ffi)/)''');

/// Platform channels: the channel classes, Flutter's own channels, any binary
/// messenger (defaultBinaryMessenger, binaryMessenger:) and raw platform
/// messages. Flutter's high-level services (Clipboard, HapticFeedback) stay
/// allowed. Same pattern as tool/ruflet_native/check_no_channels.sh.
final _channel = RegExp(r'\b(MethodChannel|EventChannel|BasicMessageChannel|'
    r'OptionalMethodChannel|SystemChannels|sendPlatformMessage|'
    r'setMessageHandler|channelBuffers)\b|[Bb]inaryMessenger');

/// Native sources, prebuilt native binaries and libraries, and the folders
/// and build files that only exist for them.
final _nativeFile = RegExp(
    r'\.(java|kt|kts|groovy|scala|m|mm|h|hh|hpp|hxx|c|cc|cpp|cxx|swift|s|S|asm|'
    r'rs|go|zig|jar|aar|class|dex|so|a|o|dylib|dll|lib|tbd)$|'
    r'(^|/)(jniLibs|[^/]+\.(xc)?framework)/|'
    r'(^|/)(CMakeLists\.txt|Makefile|Cargo\.toml|Package\.swift)$');

/// The package names declared under [section] of a pubspec (two-space keys;
/// comments and nested keys skipped).
Set<String> _pubspecSection(String pubspec, String section) {
  final names = <String>{};
  var inside = false;
  for (final line in pubspec.split('\n')) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inside = line.startsWith('$section:');
      continue;
    }
    final name = RegExp(r'^  ([A-Za-z0-9_]+)\s*:').firstMatch(line);
    if (inside && name != null) names.add(name[1]!);
  }
  return names;
}

bool _isFfiFile(String path) =>
    path.contains('/src/ffi/android/') ||
    path.contains('/src/ffi/ios/') ||
    path.contains('/src/ffi/common/') ||
    path.endsWith('/src/ffi/native.dart') ||
    RegExp(r'_(android|ios|native)\.dart$').hasMatch(path);

void main() {
  test('no platform channels in lib/', () {
    for (final file in _dart('lib')) {
      expect(_channel.hasMatch(_code(file)), isFalse, reason: file.path);
    }
  });

  test('the channel pattern catches the bypasses', () {
    // Guards the pattern against being narrowed again.
    for (final code in [
      "const MethodChannel('x')",
      "SystemChannels.platform.invokeMethod<void>('HapticFeedback.vibrate')",
      "ServicesBinding.instance.defaultBinaryMessenger.send('x', null)",
      'EventChannel(name, binaryMessenger: messenger)',
      "PlatformDispatcher.instance.sendPlatformMessage('x', null, null)",
    ]) {
      expect(_channel.hasMatch(code), isTrue, reason: code);
    }
    expect(_channel.hasMatch('await Clipboard.setData(data)'), isFalse);
  });

  test('lib/ imports no plugin package with native code', () {
    final import = RegExp(r'''import\s+['"]package:([a-z0-9_]+)/''');
    for (final file in _dart('lib')) {
      for (final m in import.allMatches(_code(file))) {
        expect(_allowedPackages, contains(m[1]), reason: '${file.path}: ${m[1]}');
      }
    }
  });

  test('pubspec.yaml depends on no plugin package with native code', () {
    // A dependency is built into the app (and registered by Flutter's
    // generated plugin registrant) even when no file imports it.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = _pubspecSection(pubspec, 'dependencies');
    expect(dependencies, containsAll(['flutter', 'ruflet', 'jni', 'objective_c']));
    for (final name in dependencies) {
      expect(_allowedPackages, contains(name), reason: 'pubspec.yaml: $name');
    }
  });

  test('the pubspec check catches a native plugin dependency', () {
    // Guards the parser against reading nothing.
    const pubspec = '''
name: ruflet_native
dependencies:
  flutter:
    sdk: flutter
  # a comment
  jni: '>=1.2.1 <1.3.0'
  torch_light: 1.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
''';
    expect(_pubspecSection(pubspec, 'dependencies'),
        {'flutter', 'jni', 'torch_light'});
    expect(_allowedPackages, isNot(contains('torch_light')));
  });

  test('only FFI files import dart:ffi, jni or objective_c', () {
    for (final file in _dart('lib')) {
      if (_isFfiFile(file.path)) continue;
      expect(_ffiImport.hasMatch(_code(file)), isFalse, reason: file.path);
    }
  });

  test('FFI code is reached only through conditional imports', () {
    final direct = RegExp(
        r'''(import|export)\s+['"][^'"]*(_native|_android|_ios)\.dart['"]\s*;''');
    for (final file in _dart('lib')) {
      if (_isFfiFile(file.path)) continue;
      expect(direct.hasMatch(_code(file)), isFalse, reason: file.path);
    }
    for (final file in _dart('lib').where((f) => f.path.endsWith('_select.dart'))) {
      expect(_code(file), contains('if (dart.library.ffi)'), reason: file.path);
    }
    expect(File('lib/src/ffi/runtime.dart').readAsStringSync(),
        contains("export 'stub.dart' if (dart.library.ffi) 'native.dart'"));
  });

  test('the package has no native source file and no prebuilt binary', () {
    // Same patterns as tool/ruflet_native/check_no_native_sources.sh.
    for (final entity in Directory('.').listSync(recursive: true)) {
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/.dart_tool/') || path.contains('/build/')) continue;
      if (entity is File) {
        expect(_nativeFile.hasMatch(path), isFalse, reason: path);
      }
    }
  });

  test('the native-file pattern catches sources, binaries and their folders',
      () {
    for (final path in [
      './android/src/main/kotlin/X.kt',
      './android/src/main/java/X.java',
      './ios/Classes/X.m',
      './ios/Classes/X.swift',
      './src/x.c',
      './android/libs/x.jar',
      './android/libs/x.aar',
      './android/src/main/jniLibs/arm64-v8a/libx.so',
      './ios/x.xcframework/Info.plist',
      './ios/libx.a',
      './rust/src/lib.rs',
      './src/CMakeLists.txt',
      './ios/Package.swift',
    ]) {
      expect(_nativeFile.hasMatch(path), isTrue, reason: path);
    }
    for (final path in [
      './android/build.gradle',
      './android/features/CORE',
      './android/proguard/shared.pro',
      './ios/ruflet_native.podspec',
      './ios/Resources/PrivacyInfo.xcprivacy',
      './lib/src/ffi/ios/c/libsystem.dart',
    ]) {
      expect(_nativeFile.hasMatch(path), isFalse, reason: path);
    }
  });

  test('the CI scripts use the same patterns', () {
    // tool/ is not part of the package (absent from synced copies).
    final tool = Directory('../../../tool/ruflet_native');
    if (!tool.existsSync()) return;
    final channels =
        File('${tool.path}/check_no_channels.sh').readAsStringSync();
    final sources =
        File('${tool.path}/check_no_native_sources.sh').readAsStringSync();
    expect(channels, contains("grep -rnE '${_channel.pattern}' lib"));
    expect(sources, contains("grep -E '${_nativeFile.pattern}'"));
  });
}
