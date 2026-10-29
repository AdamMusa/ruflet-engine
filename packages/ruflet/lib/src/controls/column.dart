import 'package:flutter/widgets.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/alignment.dart';
import '../utils/numbers.dart';
import 'adaptive_refresh_scroll_view.dart';
import 'base_controls.dart';
import 'end_reached_listener.dart';
import 'scroll_notification_control.dart';
import 'scroll_slivers.dart';
import 'scrollable_control.dart';

class ColumnControl extends StatelessWidget {
  final Control control;

  const ColumnControl({
    super.key,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("Column build: ${control.id}");

    var spacing = control.getDouble("spacing", 10)!;
    var alignment = control.getString("alignment");
    var tight = control.getBool("tight", false)!;
    var wrap = control.getBool("wrap", false)!;
    var horizontalAlignment = control.getString("horizontal_alignment");
    var intrinsicWidth = control.getBool("intrinsic_width", false)!;
    var controls = control.buildWidgets("controls");

    Widget child = wrap
        ? Wrap(
            direction: Axis.vertical,
            spacing: spacing,
            runSpacing: control.getDouble("run_spacing", 10)!,
            alignment: parseWrapAlignment(alignment, WrapAlignment.start)!,
            runAlignment: parseWrapAlignment(
                control.getString("run_alignment"), WrapAlignment.start)!,
            crossAxisAlignment: parseWrapCrossAlignment(
                horizontalAlignment, WrapCrossAlignment.start)!,
            children: controls,
          )
        : Column(
            mainAxisAlignment:
                parseMainAxisAlignment(alignment, MainAxisAlignment.start)!,
            spacing: spacing,
            mainAxisSize: tight ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: parseCrossAxisAlignment(
                horizontalAlignment, CrossAxisAlignment.start)!,
            children: controls,
          );

    if (intrinsicWidth) {
      child = IntrinsicWidth(child: child);
    }

    final onRefresh = control.getBool("on_refresh", false)!;
    if (onRefresh && wrap) {
      debugPrint("Column ${control.id}: on_refresh is ignored when wrap is on");
    }
    if (onRefresh && !wrap) {
      // A refreshable Column always scrolls vertically, even without `scroll`.
      child = _RefreshableColumn(control: control, child: child);
    } else {
      child = ScrollableControl(
        control: control,
        scrollDirection: wrap ? Axis.horizontal : Axis.vertical,
        wrapIntoScrollableView: true,
        child: child,
      );
    }

    if (control.getBool("on_scroll", false)!) {
      child = ScrollNotificationControl(control: control, child: child);
    }

    if (control.getBool("on_end_reached", false)!) {
      child = EndReachedListener(control: control, child: child);
    }

    return LayoutControl(control: control, child: child);
  }
}

/// The scroll view of a Column with `on_refresh`. It owns the controller that
/// both the pull-to-refresh view and [ScrollableControl] (`scroll`,
/// `auto_scroll`, `scroll_to`) use, since [ColumnControl] is stateless.
class _RefreshableColumn extends StatefulWidget {
  final Control control;
  final Widget child;

  const _RefreshableColumn({required this.control, required this.child});

  @override
  State<_RefreshableColumn> createState() => _RefreshableColumnState();
}

class _RefreshableColumnState extends State<_RefreshableColumn> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ScrollableControl(
        control: widget.control,
        scrollDirection: Axis.vertical,
        scrollController: _controller,
        child: AdaptiveRefreshScrollView(
          control: widget.control,
          controller: _controller,
          shrinkWrap: constraints.maxHeight == double.infinity,
          slivers: [
            boxSliver(widget.child,
                fillViewport: hasExpandedChild(widget.control))
          ],
        ),
      ),
    );
  }
}
