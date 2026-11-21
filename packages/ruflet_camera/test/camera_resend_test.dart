// A Camera Ruby re-sends keeps its invoke listener. A parent re-sends all of
// its children (`col.children << x; page.update`), so the client gets a new
// Control object with the same id while Flutter keeps the camera's State
// (and its open CameraController) and only hands it the new object. Ruby's
// invokes look the id up and reach the new object, so the listener must
// move there.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_camera/src/camera.dart';

void main() {
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://camera-resend'),
      assetsDir: '',
      extensions: const [],
      multiView: false);

  Widget app(Control control) => Directionality(
      textDirection: TextDirection.ltr, child: CameraControl(control: control));

  for (final newId in [false, true]) {
    final how = newId ? 'Ruby puts a new Camera in its slot' : 'it is re-sent';
    testWidgets('a Camera keeps its invoke listener when $how',
        (tester) async {
      final before =
          Control.fromMap({'_c': 'Camera', '_i': 2}, backend);
      await tester.pumpWidget(app(before));
      final state = tester.state(find.byType(CameraControl));
      expect(before.debugInvokeMethodListenerCount, 1);

      final after =
          Control.fromMap({'_c': 'Camera', '_i': newId ? 3 : 2}, backend);
      await tester.pumpWidget(app(after));
      expect(identical(tester.state(find.byType(CameraControl)), state),
          isTrue);
      expect(after.debugInvokeMethodListenerCount, 1);
      expect(before.debugInvokeMethodListenerCount, 0);

      await tester.pumpWidget(const SizedBox());
      expect(after.debugInvokeMethodListenerCount, 0);
    });
  }
}
