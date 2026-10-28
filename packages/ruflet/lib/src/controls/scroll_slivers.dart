import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/edge_insets.dart';
import '../utils/layout.dart';
import '../utils/keys.dart';
import '../utils/numbers.dart';
import 'control_widget.dart';

/// Sliver builders shared by the scrollable controls.
///
/// A refreshable ListView/GridView/Column is a `CustomScrollView` (the
/// Cupertino refresh control is a sliver), so these builders reproduce exactly
/// the slivers that `ListView`/`GridView` build internally. That keeps the
/// geometry of a list identical with and without `on_refresh`.

/// The separator a Ruby ListView draws between items when `spacing > 0`.
Widget listSeparator(
    {required bool horizontal,
    required double spacing,
    required double dividerThickness}) {
  if (dividerThickness == 0) {
    return SizedBox(
        width: horizontal ? spacing : null,
        height: horizontal ? null : spacing);
  }
  return SizedBox(
    width: horizontal ? spacing : dividerThickness,
    height: horizontal ? dividerThickness : spacing,
    child: Center(
      child: SizedBox(
        width: horizontal ? dividerThickness : double.infinity,
        height: horizontal ? double.infinity : dividerThickness,
        child: const ColoredBox(color: Color(0x1F000000)),
      ),
    ),
  );
}

Widget _item(Control item) => ControlWidget(
      key: ValueKey(item.getKey("key")?.value ?? item.id),
      control: item,
    );

/// Wraps [sliver] in the list padding the way `BoxScrollView` does: an explicit
/// `padding`, or else the main-axis media padding (safe area), leaving the
/// cross-axis media padding to the items.
Widget paddedSliver(
    BuildContext context, EdgeInsets? padding, Axis axis, Widget sliver) {
  EdgeInsetsGeometry? effectivePadding = padding;
  if (padding == null) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery != null) {
      final horizontalPadding =
          mediaQuery.padding.copyWith(top: 0.0, bottom: 0.0);
      final verticalPadding =
          mediaQuery.padding.copyWith(left: 0.0, right: 0.0);
      effectivePadding =
          axis == Axis.vertical ? verticalPadding : horizontalPadding;
      sliver = MediaQuery(
        data: mediaQuery.copyWith(
            padding:
                axis == Axis.vertical ? horizontalPadding : verticalPadding),
        child: sliver,
      );
    }
  }
  return effectivePadding == null
      ? sliver
      : SliverPadding(padding: effectivePadding, sliver: sliver);
}

/// The item sliver of a Ruby ListView (`spacing`, `divider_thickness`,
/// `item_extent`, `prototype_item`/`first_item_prototype`,
/// `build_controls_on_demand`, `padding`), matching list_view.dart's box path.
Widget listViewSliver(BuildContext context, Control control,
    List<Control> items, Widget? prototypeItem) {
  final horizontal = control.getBool("horizontal", false)!;
  final spacing = control.getDouble("spacing", 0)!;
  final dividerThickness = control.getDouble("divider_thickness", 0)!;
  final itemExtent = control.getDouble("item_extent");
  final buildControlsOnDemand =
      control.getBool("build_controls_on_demand", true)!;
  Widget separator() => listSeparator(
      horizontal: horizontal,
      spacing: spacing,
      dividerThickness: dividerThickness);

  Widget layout(
      SliverChildDelegate delegate, double? extent, Widget? prototype) {
    if (extent != null) {
      return SliverFixedExtentList(delegate: delegate, itemExtent: extent);
    }
    if (prototype != null) {
      return SliverPrototypeExtentList(
          delegate: delegate, prototypeItem: prototype);
    }
    return SliverList(delegate: delegate);
  }

  Widget sliver;
  if (!buildControlsOnDemand) {
    final children = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      children.add(_item(items[index]));
      if (spacing > 0 && index < items.length - 1) children.add(separator());
    }
    sliver = layout(SliverChildListDelegate(children),
        spacing > 0 ? null : itemExtent, spacing > 0 ? null : prototypeItem);
  } else if (spacing > 0) {
    sliver = SliverList.separated(
      itemCount: items.length,
      itemBuilder: (context, index) => _item(items[index]),
      separatorBuilder: (context, index) => separator(),
    );
  } else {
    sliver = layout(
        SliverChildBuilderDelegate((context, index) => _item(items[index]),
            childCount: items.length),
        itemExtent,
        prototypeItem);
  }
  return paddedSliver(context, control.getPadding("padding"),
      horizontal ? Axis.horizontal : Axis.vertical, sliver);
}

/// The grid delegate of a Ruby GridView (`runs_count`/`max_extent`,
/// `spacing`, `run_spacing`, `child_aspect_ratio`).
SliverGridDelegate gridDelegateFor(Control control) {
  final runsCount = control.getInt("runs_count", 1)!;
  final maxExtent = control.getDouble("max_extent");
  final spacing = control.getDouble("spacing", 10)!;
  final runSpacing = control.getDouble("run_spacing", 10)!;
  final childAspectRatio = control.getDouble("child_aspect_ratio", 1)!;
  return maxExtent == null
      ? SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: runsCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio)
      : SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          mainAxisSpacing: spacing,
          crossAxisSpacing: runSpacing,
          childAspectRatio: childAspectRatio);
}

/// The item sliver of a Ruby GridView, matching grid_view.dart's box path.
Widget gridViewSliver(
    BuildContext context, Control control, List<Control> items) {
  final horizontal = control.getBool("horizontal", false)!;
  final buildControlsOnDemand =
      control.getBool("build_controls_on_demand", true)!;
  final gridDelegate = gridDelegateFor(control);
  final Widget sliver = buildControlsOnDemand
      ? SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemCount: items.length,
          itemBuilder: (context, index) => _item(items[index]),
        )
      : SliverGrid(
          gridDelegate: gridDelegate,
          delegate: SliverChildListDelegate(items.map(_item).toList()),
        );
  return paddedSliver(context, control.getPadding("padding"),
      horizontal ? Axis.horizontal : Axis.vertical, sliver);
}

/// Whether a flex host (Column, View) has a child that Ruby marked `expand`;
/// such a child becomes `Expanded`, which needs a bounded main axis.
bool hasExpandedChild(Control control) => control
    .children("controls")
    .any((child) => (child.getExpand("expand") ?? 0) > 0);

/// A box (a Column, a page body) as a sliver of a refreshable scroll view.
///
/// The box is at least as tall as the viewport, so main-axis alignment
/// (`alignment: "center"`, `"end"`, ...) lays out exactly as it does without
/// scrolling, and it grows past the viewport (and scrolls) when the content is
/// taller. Unlike `SliverFillRemaining` this never asks the box for its
/// intrinsic size, which LayoutBuilder-based children cannot answer. The
/// minimum ignores preceding slivers, so while the iOS refresh control is open
/// the content is pushed down (as in native iOS) instead of re-aligned.
///
/// With [fillViewport] the box is exactly one viewport tall instead, so
/// `expand` children keep flexing (an unbounded box would make them throw);
/// the view can then still be pulled, but not scrolled further.
Widget boxSliver(Widget child, {bool fillViewport = false}) =>
    SliverLayoutBuilder(
      builder: (context, constraints) {
        // A shrink-wrapping (unbounded) viewport reports an infinite extent.
        final viewport = constraints.viewportMainAxisExtent;
        final extent = viewport.isFinite ? math.max(0.0, viewport) : 0.0;
        final vertical = constraints.axis == Axis.vertical;
        final BoxConstraints box = fillViewport && viewport.isFinite
            ? (vertical
                ? BoxConstraints.tightFor(height: extent)
                : BoxConstraints.tightFor(width: extent))
            : (vertical
                ? BoxConstraints(minHeight: extent)
                : BoxConstraints(minWidth: extent));
        return SliverToBoxAdapter(
          child: ConstrainedBox(constraints: box, child: child),
        );
      },
    );
