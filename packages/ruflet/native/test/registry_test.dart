// The registry is complete from PR 1 and consistent with the build files.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_native/src/feature.dart';
import 'package:ruflet_native/src/registry.dart';

const plannedCore = [
  'battery', 'connectivity', 'clipboard', 'share', 'url_launcher',
  'shared_preferences', 'storage_paths', 'file_picker', 'sensors',
  'shake_detector', 'screen_brightness', 'wakelock', 'haptic_feedback',
  'device_info',
];
const plannedExtensions = [
  'flashlight', 'secure_storage', 'local_auth', 'geolocator',
  'permission_handler', 'audio', 'audio_recorder', 'camera',
  'qrcode_scanner', 'video',
];

/// Features that are implemented (no longer inert stubs).
const implemented = {'flashlight'};

void main() {
  test('every planned feature has an entry, once', () {
    expect([for (final f in coreFeatures) f.name], plannedCore);
    expect([for (final f in extensionFeatures) f.name], plannedExtensions);
    expect(allFeatures.map((f) => f.name).toSet(), hasLength(allFeatures.length));
  });

  test('control types are unique across features', () {
    final seen = <String, String>{};
    for (final feature in allFeatures) {
      for (final type in feature.controlTypes) {
        expect(seen.containsKey(type), isFalse,
            reason: '$type claimed by ${seen[type]} and ${feature.name}');
        seen[type] = feature.name;
      }
    }
  });

  test('only implemented features leave the stub state', () {
    for (final feature in allFeatures) {
      expect(feature.isStub, !implemented.contains(feature.name),
          reason: feature.name);
    }
  });

  test('android/features/CORE equals coreFeatures', () {
    final lines = File('android/features/CORE')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    expect(lines, plannedCore);
  });

  test('each feature has its folder, NOTICE and (extensions) entry library',
      () {
    for (final feature in allFeatures) {
      expect(File('lib/src/${feature.name}/feature.dart').existsSync(), isTrue,
          reason: feature.name);
      expect(File('NOTICES/${feature.name}.md').existsSync(), isTrue,
          reason: feature.name);
    }
    for (final feature in extensionFeatures) {
      final entry = File('lib/${feature.name}.dart');
      expect(entry.existsSync(), isTrue, reason: feature.name);
      expect(entry.readAsStringSync(),
          contains('class Extension extends RufletNativeExtension'));
    }
  });

  test('Android feature files are named after planned features', () {
    final names = {for (final f in allFeatures) f.name};
    for (final file in Directory('android/features').listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (name == 'CORE') continue;
      expect(names, contains(name.substring(0, name.lastIndexOf('.'))),
          reason: name);
    }
  });

  test('extension features keep their wrapper behavior off Android/iOS', () {
    // Flashlight answers its own "supported only" error (self); features
    // that land later declare delegate or wrapper.
    expect(allFeatures.firstWhere((f) => f.name == 'flashlight').offPlatform,
        OffPlatform.self);
    for (final feature in coreFeatures) {
      expect(feature.offPlatform, OffPlatform.delegate, reason: feature.name);
    }
  });
}
