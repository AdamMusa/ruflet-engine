import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import '../widgets/ruflet_store_mixin.dart';

class CupertinoContextMenuControl extends StatefulWidget {
  final Control control;

  CupertinoContextMenuControl({Key? key, required this.control})
      : super(key: key ?? ValueKey("control_${control.id}"));

  @override
  State<CupertinoContextMenuControl> createState() =>
      _CupertinoContextMenuControlState();
}

class _CupertinoContextMenuControlState
    extends State<CupertinoContextMenuControl> with RufletStoreMixin {
  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    switch (name) {
      case "open":
        // CupertinoContextMenu opens only from its own long-press gesture:
        // the open routine is private and there is no controller (Flutter
        // 3.41), mirroring UIKit, where context menus cannot be presented
        // from code either. Reply at once instead of letting Ruby time out.
        throw UnsupportedError(
            "ContextMenu.open is not supported on iOS and macOS: the native "
            "context menu opens only from the user's long press, and Flutter's "
            "CupertinoContextMenu has no API to open it programmatically. "
            "Use an action_sheet to present the same actions from code.");
      default:
        throw Exception("Unknown ContextMenu method: $name");
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("CupertinoContextMenu build ($hashCode): ${widget.control.id}");

    var content = widget.control.buildWidget("content");
    var actions = widget.control.buildWidgets("actions");
    if (actions.isEmpty) {
      actions = widget.control.buildWidgets("items");
    }

    if (actions.isEmpty) {
      return const ErrorControl(
          "at least one action in CupertinoContextMenu.actions must be visible");
    }
    if (content == null) {
      return const ErrorControl("CupertinoContextMenu.content must be visible");
    }

    return CupertinoContextMenu(
      enableHapticFeedback:
          widget.control.getBool("enable_haptic_feedback", false)!,
      actions: actions,
      child: content,
    );
  }
}
