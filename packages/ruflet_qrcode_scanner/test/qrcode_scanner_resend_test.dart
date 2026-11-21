// A QrcodeScanner Ruby re-sends unchanged keeps its invoke listener. A
// parent re-sends all of its children (`col.children << x; page.update`), so
// the client gets a new Control object, equal to the old one, with the same
// id. Control equality compares properties, so the rebind must compare
// identity.
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:ruflet/ruflet.dart";
import "package:ruflet_qrcode_scanner/src/qrcode_scanner.dart";

void main() {
  final backend = RufletBackend(
    pageUri: Uri.parse("ruflet://qrcode-resend"),
    assetsDir: "",
    extensions: const [],
    multiView: false,
  );

  Widget app(Control control) => Directionality(
        textDirection: TextDirection.ltr,
        child: QrCodeScannerControl(control: control),
      );

  Control scanner() => Control.fromMap(
      {"_c": "QrcodeScanner", "_i": 2, "auto_start": false}, backend);

  testWidgets("an unchanged re-send moves the listener", (tester) async {
    final before = scanner();
    await tester.pumpWidget(app(before));
    expect(before.debugInvokeMethodListenerCount, 1);

    final after = scanner();
    expect(after == before, isTrue);
    await tester.pumpWidget(app(after));
    expect(after.debugInvokeMethodListenerCount, 1);
    expect(before.debugInvokeMethodListenerCount, 0);

    await tester.pumpWidget(const SizedBox());
    expect(after.debugInvokeMethodListenerCount, 0);
  });
}
