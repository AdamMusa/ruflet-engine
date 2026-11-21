// A CodeEditor Ruby re-sends keeps answering Ruby's methods. A parent
// re-sends all of its children (`col.children << x; page.update`), so the
// client gets a new Control object with the same id while the editor's State
// stays; its invoke listener must move to that object.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_code_editor/ruflet_code_editor.dart';

import 'support/harness.dart';

const _timeout = Duration(seconds: 5);

Map<String, dynamic> _editor() =>
    {'_c': 'CodeEditor', '_i': 2, 'value': 'puts :ok', 'language': 'ruby'};

void main() {
  for (final design in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$design a re-sent CodeEditor still answers focus',
        (tester) async {
      final m = await mountWire(
          tester,
          design,
          {
            '_c': 'Column',
            '_i': 1,
            'controls': [_editor()]
          },
          extensions: [Extension()]);
      final state = tester.state(find.byType(EditableText));
      final before = m.control(2);

      m.root.applyPatch([
        [0],
        [
          0,
          0,
          'controls',
          [
            _editor(),
            {'_c': 'Text', '_i': 3, 'value': 'appended'}
          ]
        ],
      ], m.backend);
      await tester.pumpAndSettle();
      expect(identical(m.control(2), before), isFalse);
      expect(identical(tester.state(find.byType(EditableText)), state), isTrue);

      Object? error;
      await tester.runAsync(() => m
          .control(2)
          .invokeMethod('focus', null, _timeout)
          .then((_) {}, onError: (Object e) => error = e));
      await tester.pump();
      expect(error, isNull);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);
      expect(before.debugInvokeMethodListenerCount, 0);
    });
  }
}
