// Ruby's `key:` reaches the widget this extension builds, as it does for
// every core control: a value key keeps the control's identity when Ruby
// moves it, and a scroll key's GlobalKey lets `scroll_to(scroll_key:)` find
// it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_code_editor/src/extension.dart';

void main() {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://extension-key'),
      assetsDir: '',
      extensions: const [],
      multiView: false);

  for (final type in ['CodeEditor']) {
    test('$type keeps the key Ruby gives it', () {
      final control =
          Control(id: 1, type: type, properties: {}, backend: backend);
      for (final Key key in [const ValueKey('k'), GlobalKey()]) {
        expect(Extension().createWidget(key, control)?.key, same(key));
      }
    });
  }
}
