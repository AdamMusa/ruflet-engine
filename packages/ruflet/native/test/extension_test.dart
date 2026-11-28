// RufletNativeExtension: routing by control type, the off-platform modes,
// one install per process and the core hook entry.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native/ruflet_native.dart';
import 'package:ruflet_native/src/glue/platform.dart';

class _Service extends RufletService {
  _Service(Control control, this.tag) : super(control: control);
  final String tag;
}

RufletService _native(Control c) => _Service(c, 'native');
Widget _widget(Key? key, Control c) => SizedBox(key: key);

int installs = 0;
void _install() => installs++;

Future<Object?>? _withoutService(
        String type, String method, Map<String, Object?> args) =>
    type == 'Clipboard' && method == 'get_image' ? Future.value('img') : null;

const _delegate = NativeFeature(
    name: 'delegate',
    controlTypes: {'Delegate'},
    createService: _native,
    createWidget: _widget);
const _self = NativeFeature(
    name: 'self',
    controlTypes: {'Self'},
    offPlatform: OffPlatform.self,
    createService: _native);
const _wrapper = NativeFeature(
    name: 'wrapper',
    controlTypes: {'Wrapper'},
    offPlatform: OffPlatform.wrapper,
    createService: _native,
    createWidget: _widget);
const _platform = NativeFeature(
    name: 'platform', install: _install, invokeWithoutService: _withoutService);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RufletBackend backend;

  setUp(() {
    backend = RufletBackend(
        pageUri: Uri.parse('ruflet://extension-test'),
        assetsDir: '',
        extensions: [],
        multiView: false);
  });
  tearDown(() => debugNativeTargetOverride = null);

  Control control(String type) =>
      Control(id: 1, type: type, properties: {}, backend: backend);

  RufletNativeExtension extension() => RufletNativeExtension.features(
      const [_delegate, _self, _wrapper, _platform],
      offPlatformService: (c) => _Service(c, 'wrapper'),
      offPlatformWidget: (key, c) => const Placeholder());

  String? tag(RufletService? s) => (s as _Service?)?.tag;

  test('on Android/iOS every feature serves its control types', () {
    debugNativeTargetOverride = true;
    final e = extension();
    expect(tag(e.createService(control('Delegate'))), 'native');
    expect(tag(e.createService(control('Self'))), 'native');
    expect(tag(e.createService(control('Wrapper'))), 'native');
    expect(e.createService(control('Battery')), isNull);
    expect(e.createWidget(null, control('Wrapper')), isA<SizedBox>());
  });

  test('off Android/iOS: delegate, self and wrapper', () {
    debugNativeTargetOverride = false;
    final e = extension();
    expect(e.createService(control('Delegate')), isNull);
    expect(tag(e.createService(control('Self'))), 'native');
    expect(tag(e.createService(control('Wrapper'))), 'wrapper');
    expect(e.createWidget(null, control('Delegate')), isNull);
    expect(e.createWidget(null, control('Wrapper')), isA<Placeholder>());
  });

  test('install runs once per process, only on Android/iOS', () {
    installs = 0;
    debugNativeTargetOverride = false;
    extension().ensureInitialized();
    expect(installs, 0);
    debugNativeTargetOverride = true;
    extension().ensureInitialized();
    extension().ensureInitialized();
    expect(installs, 1);
  });

  test('invokeWithoutService answers only what a feature handles', () async {
    debugNativeTargetOverride = true;
    final e = extension();
    expect(await e.invokeWithoutService('Clipboard', 'get_image', {}), 'img');
    expect(e.invokeWithoutService('FilePicker', 'pick_files', {}), isNull);
    debugNativeTargetOverride = false;
    expect(e.invokeWithoutService('Clipboard', 'get_image', {}), isNull);
  });

  test('RufletNativeExtension() serves the core features, all inert today',
      () {
    debugNativeTargetOverride = true;
    final core = RufletNativeExtension();
    expect(core.features, hasLength(14));
    for (final type in ['Battery', 'Clipboard', 'Accelerometer', 'Flashlight']) {
      expect(core.createService(control(type)), isNull, reason: type);
    }
  });
}
