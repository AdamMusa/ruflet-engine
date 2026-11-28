import 'package:flutter/material.dart';

/// The ruflet_native development app. The integration tests in
/// integration_test/ build their own Ruflet backends; this screen only shows
/// that the app started.
void main() {
  runApp(const MaterialApp(
    home: Scaffold(body: Center(child: Text('ruflet_native example'))),
  ));
}
