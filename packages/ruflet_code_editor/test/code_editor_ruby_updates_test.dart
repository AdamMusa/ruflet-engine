// A value, selection or language Ruby sets is Ruby's own change: the editor
// applies it without echoing it back or firing Ruby's on_change /
// on_selection_change, as the core TextField does.
// ruflet-coverage: CodeEditor
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_code_editor/ruflet_code_editor.dart';

import 'support/harness.dart';

const _subscribed = {
  'on_change': true,
  'on_selection_change': true,
  'on_focus': true,
  'on_blur': true,
};

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    group('$platform', () {
      Future<Mounted> mount(WidgetTester tester,
              [Map<String, dynamic> props = const {}]) =>
          mountWire(tester, platform, {
            '_c': 'CodeEditor',
            '_i': 1,
            'value': 'puts :ok',
            'language': 'ruby',
            ..._subscribed,
            ...props,
          }, extensions: [
            Extension()
          ]);

      EditableText editable(WidgetTester tester) =>
          tester.widget<EditableText>(find.byType(EditableText));

      testWidgets('a Ruby value is applied without change or write-back',
          (tester) async {
        final m = await mount(tester);
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        m.backend.updateControl(1, {'value': 'puts :from_ruby'}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.text, 'puts :from_ruby');
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        // The user's next keystroke (at the end) still reaches Ruby.
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'puts :from_ruby!');
        await tester.pump();
        expect(m.backend.events.where((e) => e.name == 'change').toList(),
            [(id: 1, name: 'change', data: 'puts :from_ruby!')]);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a Ruby selection is applied without selection_change',
          (tester) async {
        final m = await mount(tester, {
          'selection': {'base_offset': 0, 'extent_offset': 4}
        });
        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 0, extentOffset: 4));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        m.backend.updateControl(
            1,
            {
              'selection': {'base_offset': 5, 'extent_offset': 8}
            },
            notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 5, extentOffset: 8));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);

        // The user's next selection still reaches Ruby.
        editable(tester).controller.selection =
            const TextSelection(baseOffset: 0, extentOffset: 4);
        await tester.pump();
        expect(m.backend.events.single.name, 'selection_change');
        expect((m.backend.events.single.data as Map)['selected_text'], 'puts');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a Ruby language change keeps the selection silently',
          (tester) async {
        final m = await mount(tester, {
          'selection': {'base_offset': 5, 'extent_offset': 8}
        });
        m.backend.updateControl(1, {'language': 'python'}, notify: true);
        m.backend.updates.clear();
        await tester.pumpAndSettle();

        expect(editable(tester).controller.text, 'puts :ok');
        expect(editable(tester).controller.selection,
            const TextSelection(baseOffset: 5, extentOffset: 8));
        expect(m.backend.events, isEmpty);
        expect(m.backend.updates, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
