import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_flashlight/ruflet_flashlight.dart';

const invokeTimeout = Duration(seconds: 2);

/// A service control of wire [type] (for example the one Ruby's
/// `page.flashlight` talks to), built and started as the engine does.
Control startService(String type) {
  final backend = RufletBackend(
    pageUri: Uri.parse('ruflet://flashlight-test'),
    assetsDir: '',
    extensions: [Extension()],
    multiView: false,
  );
  final control = Control(id: 1, type: type, properties: {}, backend: backend);
  Extension().createService(control)!.init();
  control.attach();
  return control;
}

/// What the engine sends Ruby as the invoke error: `e.toString()`.
Future<String?> invokeError(Control control, String method) async {
  String? text;
  await control
      .invokeMethod(method, null, invokeTimeout)
      .then(
        (_) {},
        onError: (Object e) {
          text = e.toString();
        },
      );
  return text;
}

/// Collects what debugPrint prints until the test ends.
List<String> captureDebugPrint() {
  final lines = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => lines.add('$message');
  addTearDown(() => debugPrint = original);
  return lines;
}
