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

/// Packages lib/ may import (everything else would be a plugin with native
/// code, or an undeclared dependency).
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

bool _isFfiFile(String path) =>
    path.contains('/src/ffi/android/') ||
    path.contains('/src/ffi/ios/') ||
    path.contains('/src/ffi/common/') ||
    path.endsWith('/src/ffi/native.dart') ||
    RegExp(r'_(android|ios|native)\.dart$').hasMatch(path);

void main() {
  test('no platform channels in lib/', () {
    final channel = RegExp(r'\b(MethodChannel|EventChannel|BasicMessageChannel|'
        r'OptionalMethodChannel|BinaryMessenger)\b');
    for (final file in _dart('lib')) {
      expect(channel.hasMatch(_code(file)), isFalse, reason: file.path);
    }
  });

  test('lib/ imports no plugin package with native code', () {
    final import = RegExp(r'''import\s+['"]package:([a-z0-9_]+)/''');
    for (final file in _dart('lib')) {
      for (final m in import.allMatches(_code(file))) {
        expect(_allowedPackages, contains(m[1]), reason: '${file.path}: ${m[1]}');
      }
    }
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

  test('the package has no native source file', () {
    final native = RegExp(r'\.(java|kt|kts|m|mm|h|c|cc|cpp|cxx|swift|S|s)$');
    for (final entity in Directory('.').listSync(recursive: true)) {
      final path = entity.path;
      if (path.contains('/.dart_tool/') || path.contains('/build/')) continue;
      if (entity is File) {
        expect(native.hasMatch(path), isFalse, reason: path);
      }
    }
  });
}
