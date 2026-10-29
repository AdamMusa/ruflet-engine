import 'package:flutter/cupertino.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/error.dart';
import '../widgets/ruflet_store_mixin.dart';
import 'control_widget.dart';

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
  Widget build(BuildContext context) {
    debugPrint("CupertinoContextMenu build ($hashCode): ${widget.control.id}");

    var content = widget.control.buildWidget("content");
    var items = widget.control.children("actions");
    if (items.isEmpty) {
      items = widget.control.children("items");
    }

    if (items.isEmpty) {
      return const ErrorControl(
          "at least one action in CupertinoContextMenu.actions must be visible");
    }
    if (content == null) {
      return const ErrorControl("CupertinoContextMenu.content must be visible");
    }

    return CupertinoContextMenu(
      enableHapticFeedback:
          widget.control.getBool("enable_haptic_feedback", false)!,
      actions: items
          .map((item) => _MenuSessionAction(
              menu: this, items: items, child: ControlWidget(control: item)))
          .toList(),
      child: content,
    );
  }

  // CupertinoContextMenu has no open/close callbacks. Its actions exist only
  // while the menu route is up, so their lifetime is the menu session: the
  // last one going away closes the session, and a session without a chosen
  // item is a dismissal, as with Material's ContextMenu.
  int _openActions = 0;
  bool _selected = false;
  int _itemCount = 0;

  void _attach(int itemCount) {
    if (_openActions++ == 0) _selected = false;
    _itemCount = itemCount;
  }

  void _detach() {
    if (--_openActions == 0 && !_selected && mounted) {
      widget.control.triggerEvent("dismiss", _payload());
    }
  }

  void _select(Control item, List<Control> items) {
    _selected = true;
    widget.control.triggerEvent(
        "select",
        _payload(
            itemId: item.id,
            itemIndex: items.contains(item) ? items.indexOf(item) : null));
  }

  // Same keys as the Material ContextMenu payload. The native menu opens on
  // a primary long press and reports no pointer position.
  Map<String, dynamic> _payload({int? itemId, int? itemIndex}) => {
        "b": "primary",
        "tr": "longPress",
        "id": itemId,
        "idx": itemIndex,
        "ic": _itemCount,
        "g": null,
        "l": null,
      };
}

/// Lets a [CupertinoContextMenuActionControl] report the chosen item to the
/// enclosing ContextMenu's `on_select`.
class CupertinoContextMenuSelection extends InheritedWidget {
  final void Function(Control item) onSelected;

  const CupertinoContextMenuSelection(
      {super.key, required this.onSelected, required super.child});

  static CupertinoContextMenuSelection? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CupertinoContextMenuSelection>();

  @override
  bool updateShouldNotify(CupertinoContextMenuSelection oldWidget) => false;
}

class _MenuSessionAction extends StatefulWidget {
  final _CupertinoContextMenuControlState menu;
  final List<Control> items;
  final Widget child;

  const _MenuSessionAction(
      {required this.menu, required this.items, required this.child});

  @override
  State<_MenuSessionAction> createState() => _MenuSessionActionState();
}

class _MenuSessionActionState extends State<_MenuSessionAction> {
  late final _CupertinoContextMenuControlState _menu = widget.menu;

  @override
  void initState() {
    super.initState();
    _menu._attach(widget.items.length);
  }

  @override
  void dispose() {
    _menu._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoContextMenuSelection(
      onSelected: (item) => widget.menu._select(item, widget.items),
      child: widget.child);
}
