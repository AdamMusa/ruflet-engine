import 'package:flutter/widgets.dart';

import '../models/control.dart';

/// Answers Ruby's `invoke_method` calls for the control a [State]'s widget
/// renders, and keeps answering them when Ruby re-sends that control.
///
/// Ruby re-sends a parent's whole children list on most updates
/// (`col.controls << x; page.update`) and the page's `views` on every
/// `page.add`. The client then builds a new [Control] object with the same id
/// while Flutter keeps the existing [State] and only hands it a new widget.
/// A listener added once in `initState` would stay on the old object, and
/// every later invoke for that id would fail with "no handler ... is
/// registered". This mixin adds [onInvokeMethod] in [initState], moves it in
/// [didUpdateWidget] whenever [invokeMethodControl] is a different object,
/// and removes it in [dispose].
///
/// ```dart
/// class _MyControlState extends State<MyControl>
///     with InvokeMethodListenerMixin {
///   @override
///   Control get invokeMethodControl => widget.control;
///
///   @override
///   Future<dynamic> onInvokeMethod(String name, dynamic args) async { ... }
/// }
/// ```
mixin InvokeMethodListenerMixin<T extends StatefulWidget> on State<T> {
  Control? _listening;

  /// The control whose methods this state answers, read from [widget].
  Control get invokeMethodControl;

  /// Handles one method Ruby invokes on [invokeMethodControl].
  Future<dynamic> onInvokeMethod(String name, dynamic args);

  @override
  void initState() {
    super.initState();
    _listen(invokeMethodControl);
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final control = invokeMethodControl;
    if (!identical(control, _listening)) {
      _unlisten();
      _listen(control);
    }
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  void _listen(Control control) {
    control.addInvokeMethodListener(onInvokeMethod);
    _listening = control;
  }

  void _unlisten() {
    _listening?.removeInvokeMethodListener(onInvokeMethod);
    _listening = null;
  }
}
