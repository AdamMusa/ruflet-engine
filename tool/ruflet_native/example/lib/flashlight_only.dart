// Tree-shaking probe (spike S5): the core features plus Flashlight, as an
// app with `extensions: [flashlight]` registers them after the switch.
import 'package:flutter/material.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native/flashlight.dart' as flashlight;
import 'package:ruflet_native/ruflet_native.dart';

void main() {
  final extensions = <RufletExtension>[
    RufletNativeExtension(),
    flashlight.Extension(),
  ];
  for (final extension in extensions) {
    extension.ensureInitialized();
  }
  // A real backend and a service lookup, as the app's ServiceBinding does
  // (the backend is never connected).
  final backend = RufletBackend(
      pageUri: Uri.parse('ruflet://tree-shaking'),
      assetsDir: '',
      extensions: extensions,
      multiView: false);
  for (final extension in backend.extensions) {
    extension
        .createService(Control(
            id: 1, type: 'Flashlight', properties: {}, backend: backend))
        ?.init();
  }
  runApp(MaterialApp(home: Text('${backend.extensions.length} with flashlight')));
}
