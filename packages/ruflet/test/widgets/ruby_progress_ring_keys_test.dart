import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

Future<CircularProgressIndicator> _pumpRing(
  WidgetTester tester,
  Map<String, dynamic> props,
) async {
  final backend = RufletBackend(
    pageUri: Uri.parse('inprocess://progress-ring-keys-test'),
    assetsDir: '',
    extensions: [],
    multiView: false,
  )..platform = TargetPlatform.android;
  final control = Control.fromMap({
    '_c': 'ProgressRing',
    '_i': 1,
    ...props,
  }, backend);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: backend,
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ControlWidget(control: control),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return tester.widget<CircularProgressIndicator>(
    find.byType(CircularProgressIndicator),
  );
}

void main() {
  // The Cupertino renderer is CupertinoActivityIndicator, which has no
  // year2023 style, so only the Material ring reads Ruby's year_2023.
  for (final year2023 in [false, true]) {
    testWidgets('Material ProgressRing honors Ruby year_2023: $year2023', (
      tester,
    ) async {
      final ring = await _pumpRing(tester, {'year_2023': year2023});
      // ignore: deprecated_member_use
      expect(ring.year2023, year2023);
    });
  }

  testWidgets('Material ProgressRing leaves year2023 to the theme by default', (
    tester,
  ) async {
    final ring = await _pumpRing(tester, {});
    // ignore: deprecated_member_use
    expect(ring.year2023, isNull);
  });
}
