import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

class _RecordingBackend extends RufletBackend {
  final events = <String>[];

  _RecordingBackend(TargetPlatform platform)
    : super(
        pageUri: Uri.parse('inprocess://search-bar-tap-outside-test'),
        assetsDir: '',
        extensions: [],
        multiView: false,
      ) {
    this.platform = platform;
  }

  @override
  void triggerControlEventById(
    int controlId,
    String eventName, [
    dynamic eventData,
  ]) => events.add(eventName);

  @override
  void updateControl(
    int id,
    Map<String, dynamic> props, {
    bool dart = true,
    bool python = true,
    bool notify = false,
  }) {
    super.updateControl(id, props, dart: dart, python: false, notify: notify);
  }
}

Future<_RecordingBackend> _pumpSearchBar(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  final backend = _RecordingBackend(platform);
  final control = Control.fromMap({
    '_c': 'SearchBar',
    '_i': 1,
    'width': 300,
    'bar_hint_text': 'Search',
    'on_tap_outside_bar': true,
  }, backend);
  final body = Center(child: ControlWidget(control: control));
  await tester.pumpWidget(
    ChangeNotifierProvider<RufletBackend>.value(
      value: backend,
      child: platform == TargetPlatform.iOS
          ? CupertinoApp(home: CupertinoPageScaffold(child: body))
          : material.MaterialApp(home: material.Scaffold(body: body)),
    ),
  );
  expect(tester.takeException(), isNull);
  return backend;
}

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform SearchBar fires Ruby on_tap_outside_bar', (
      tester,
    ) async {
      final backend = await _pumpSearchBar(tester, platform);
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(backend.events, isNot(contains('tap_outside_bar')));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(backend.events.where((e) => e == 'tap_outside_bar'), hasLength(1));
    });

    testWidgets('$platform SearchBar ignores outside taps while unfocused', (
      tester,
    ) async {
      final backend = await _pumpSearchBar(tester, platform);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(backend.events, isNot(contains('tap_outside_bar')));
    });
  }
}
