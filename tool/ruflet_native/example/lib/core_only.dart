// Tree-shaking probe (SPEC §6.1, spike S5): an app that registers only the
// core features. check_tree_shaking.sh builds it in release mode and checks
// that no extension feature's class, selector or JNI names are in the
// binary.
import 'package:flutter/material.dart';
import 'package:ruflet/ruflet.dart';
import 'package:ruflet_native/ruflet_native.dart';

void main() {
  final extensions = <RufletExtension>[RufletNativeExtension()];
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
  runApp(MaterialApp(home: Text('${backend.extensions.length} core only')));
}
