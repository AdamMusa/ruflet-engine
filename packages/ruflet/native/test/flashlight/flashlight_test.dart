// The Flashlight feature against a fake torch. Ported from ruflet-engine#136
// (packages/ruflet_flashlight/test/flashlight_test.dart) with the imports
// changed; the last two tests are ruflet_native's own (its extension and
// its Android/iOS path).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native/flashlight.dart';
import 'package:ruflet_native/src/flashlight/errors.dart';
import 'package:ruflet_native/src/flashlight/flashlight_api.dart';
import 'package:ruflet_native/src/flashlight/flashlight_service.dart';
import 'package:ruflet_native/src/glue/platform.dart';

import 'support.dart';

/// Stands in for the native torch: records calls, answers or throws.
class _FakeTorch implements TorchBackend {
  final calls = <String>[];
  bool available = true;
  Object? enableError;
  Object? disableError;
  Object? availableError;

  @override
  Future<bool> isTorchAvailable() async {
    calls.add('isTorchAvailable');
    if (availableError != null) throw availableError!;
    return available;
  }

  @override
  Future<void> enableTorch() async {
    calls.add('enableTorch');
    if (enableError != null) throw enableError!;
  }

  @override
  Future<void> disableTorch() async {
    calls.add('disableTorch');
    if (disableError != null) throw disableError!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeTorch torch;

  setUp(() {
    torch = _FakeTorch();
    FlashlightControl.debugBackendOverride = torch;
  });

  tearDown(() {
    FlashlightControl.debugBackendOverride = null;
    debugDefaultTargetPlatformOverride = null;
    debugNativeTargetOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('on ${platform.name}', () {
      setUp(() => debugDefaultTargetPlatformOverride = platform);

      test('on and off reach the native torch and reply nil', () async {
        final control = startService('Flashlight');
        expect(await control.invokeMethod('on', null, invokeTimeout), isNull);
        expect(await control.invokeMethod('off', null, invokeTimeout), isNull);
        expect(torch.calls, ['enableTorch', 'disableTorch']);
      });

      test('is_available replies the native answer', () async {
        final control = startService('Flashlight');
        torch.available = true;
        expect(
          await control.invokeMethod('is_available', null, invokeTimeout),
          isTrue,
        );
        torch.available = false;
        expect(
          await control.invokeMethod('is_available', null, invokeTimeout),
          isFalse,
        );
      });

      test('errors reach Ruby with torch_light\'s exact text', () async {
        final control = startService('Flashlight');
        torch.enableError = EnableTorchNotAvailableException(
          message: 'Torch is not available',
        );
        expect(
          await invokeError(control, 'on'),
          '[EnableTorchNotAvailableException: Torch is not available]',
        );
        torch.disableError = DisableTorchExistentUserException(
          message: 'Could not disable torch',
        );
        expect(
          await invokeError(control, 'off'),
          '[DisableTorchExistentUserException: Could not disable torch]',
        );
        torch.availableError = EnableTorchException(
          message:
              'Could not determine if the device has a torch, please '
              'make sure that you are doing this on a real device.',
        );
        expect(
          await invokeError(control, 'is_available'),
          '[EnableTorchException: Could not determine if the device has a '
          'torch, please make sure that you are doing this on a real '
          'device.]',
        );
      });

      test('an unknown method is reported as before', () async {
        final control = startService('Flashlight');
        expect(
          await invokeError(control, 'blink'),
          'Exception: Unknown Flashlight method: blink',
        );
        expect(torch.calls, isEmpty);
      });
    });
  }

  test(
    'other platforms keep the old error and never touch native code',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final control = startService('Flashlight');
      for (final method in ['on', 'off', 'is_available']) {
        expect(
          await invokeError(control, method),
          'Exception: Flashlight control is supported only on Android and '
          'iOS devices.',
        );
      }
      expect(torch.calls, isEmpty);
    },
  );

  test('every exception prints exactly as torch_light 1.1.0 printed it', () {
    expect(EnableTorchException().toString(), '[EnableTorchException]');
    expect(
      EnableTorchException(message: 'x').toString(),
      '[EnableTorchException: x]',
    );
    expect(
      EnableTorchExistentUserException(message: 'x').toString(),
      '[EnableTorchExistentUserException: x]',
    );
    expect(
      EnableTorchNotAvailableException().toString(),
      '[EnableTorchNotAvailableException]',
    );
    expect(
      DisableTorchException(message: 'x').toString(),
      '[DisableTorchException: x]',
    );
    expect(
      DisableTorchExistentUserException().toString(),
      '[DisableTorchExistentUserException]',
    );
    expect(
      DisableTorchNotAvailableException(message: 'x').toString(),
      '[DisableTorchNotAvailableException: x]',
    );
  });

  test('the extension serves Flashlight on the Android/iOS path too', () async {
    debugNativeTargetOverride = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final control = startService('Flashlight');
    expect(
      await control.invokeMethod('is_available', null, invokeTimeout),
      isTrue,
    );
    expect(await control.invokeMethod('on', null, invokeTimeout), isNull);
    expect(torch.calls, ['isTorchAvailable', 'enableTorch']);
  });

  test('Flashlight is the only control type of the flashlight entry', () {
    final extension = Extension();
    expect(extension.features.single.controlTypes, {'Flashlight'});
    final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://flashlight-test'),
      assetsDir: '',
      extensions: [extension],
      multiView: false,
    );
    final battery = Control(
      id: 2,
      type: 'Battery',
      properties: {},
      backend: backend,
    );
    expect(extension.createService(battery), isNull);
  });
}
