import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import '../widgets/platform_badge.dart';
import '../widgets/invoke_method_listener_mixin.dart';

class KeyboardListenerControl extends StatefulWidget {
  final Control control;

  KeyboardListenerControl({Key? key, required this.control})
      : super(key: ValueKey("control_${control.id}"));

  @override
  State<KeyboardListenerControl> createState() =>
      _KeyboardListenerControlState();
}

class _KeyboardListenerControlState extends State<KeyboardListenerControl>
    with InvokeMethodListenerMixin {
  @override
  Control get invokeMethodControl => widget.control;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Future<dynamic> onInvokeMethod(String name, dynamic args) async {
    debugPrint("KeyboardListener.$name($args)");
    switch (name) {
      case "focus":
        _focusNode.requestFocus();
      default:
        throw Exception("Unknown KeyboardListener method: $name");
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("KeyboardListener build: ${widget.control.id}");

    var content = widget.control.buildWidget("content");

    if (content == null) {
      return const ErrorControl("KeyboardListener control has no content.");
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: widget.control.getBool("autofocus", false)!,
      includeSemantics: widget.control.getBool("include_semantics", true)!,
      onKeyEvent: (keyEvent) {
        if (keyEvent is KeyDownEvent) {
          widget.control
              .triggerEvent("key_down", {"key": keyEvent.logicalKey.keyLabel});
        } else if (keyEvent is KeyUpEvent) {
          widget.control
              .triggerEvent("key_up", {"key": keyEvent.logicalKey.keyLabel});
        } else if (keyEvent is KeyRepeatEvent) {
          widget.control.triggerEvent(
              "key_repeat", {"key": keyEvent.logicalKey.keyLabel});
        }
      },
      child: PlatformControlBadge(control: widget.control, child: content),
    );
  }
}
