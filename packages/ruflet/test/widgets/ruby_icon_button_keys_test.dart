// IconButton keys both designs now honor through IconButtonCore.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';

import '../support/control_harness.dart';

Map<String, dynamic> _iconButton(Map<String, dynamic> props) => {
      '_c': 'Column',
      '_i': 1900,
      'controls': [
        {'_c': 'IconButton', '_i': 1901, 'icon': 0x10000, ...props}
      ],
    };

Color? _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon)).color;

void main() {
  testWidgets('Material IconButton honors the Ruby style map', (tester) async {
    await mountWire(
        tester,
        HarnessDesign.android,
        _iconButton({
          'style': {'bgcolor': '#eeeeee'}
        }));
    final native =
        tester.widget<material.IconButton>(find.byType(material.IconButton));
    expect(native.style?.backgroundColor?.resolve({}), const Color(0xffeeeeee));
  });

  testWidgets('Cupertino IconButton honors selected_icon_color',
      (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _iconButton({
          'selected': true,
          'icon_color': '#00ff00',
          'selected_icon_color': '#ff0000',
        }));
    expect(_iconColor(tester), const Color(0xffff0000));
  });

  testWidgets('Cupertino IconButton honors disabled_color', (tester) async {
    await mountWire(
        tester,
        HarnessDesign.ios,
        _iconButton({
          'disabled': true,
          'icon_color': '#00ff00',
          'disabled_color': '#888888',
        }));
    expect(_iconColor(tester), const Color(0xff888888));
    expect(find.byType(CupertinoButton), findsOneWidget);
  });
}
