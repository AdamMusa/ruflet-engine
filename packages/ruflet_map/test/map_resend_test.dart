// A Map Ruby re-sends keeps answering Ruby's camera methods. A parent
// re-sends all of its children (`col.children << x; page.update`), so the
// client gets a new Control object with the same id while the map's State
// stays; its invoke listener must move to that object.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_map/ruflet_map.dart';

import 'support/harness.dart';

Map<String, dynamic> _map() => {
      '_c': 'Map',
      '_i': 2,
      'width': 400,
      'height': 300,
      'initial_center': {'latitude': 51.5, 'longitude': -0.09},
      'initial_zoom': 13,
      'layers': <Object>[],
    };

void main() {
  for (final design in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$design a re-sent Map still answers zoom_in', (tester) async {
      final m = await mountWire(
          tester,
          design,
          {
            '_c': 'Column',
            '_i': 1,
            'controls': [_map()]
          },
          extensions: [Extension()]);
      final before = m.control(2);

      m.root.applyPatch([
        [0],
        [
          0,
          0,
          'controls',
          [
            _map(),
            {'_c': 'Text', '_i': 3, 'value': 'appended'}
          ]
        ],
      ], m.backend);
      await tester.pumpAndSettle();
      final after = m.control(2);
      expect(identical(after, before), isFalse);

      Object? error;
      var settled = false;
      unawaited(after
          .invokeMethod('zoom_in', null, const Duration(seconds: 5))
          .then((_) {}, onError: (Object e) => error = e)
          .whenComplete(() => settled = true));
      await tester.pumpAndSettle();
      expect(settled, isTrue);
      expect(error, isNull);
      expect(tester.widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!.camera.zoom, 14.0);
      expect(before.debugInvokeMethodListenerCount, 0);
    });
  }
}
