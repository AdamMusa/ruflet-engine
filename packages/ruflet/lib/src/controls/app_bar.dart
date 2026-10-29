import '../utils/material_style_theme.dart';
import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/borders.dart';
import '../utils/colors.dart';
import '../utils/edge_insets.dart';
import '../utils/misc.dart';
import '../utils/numbers.dart';
import '../utils/text.dart';
import '../utils/theme.dart';
import 'base_controls.dart';

class AppBarControl extends StatelessWidget implements PreferredSizeWidget {
  final Control control;

  // Material 3 large top app bar, expanded state: a 64 dp toolbar plus an
  // 88 dp area holding the headline title (152 dp in total). Collapsing on
  // scroll belongs to SliverAppBar.
  static const double _largeToolbarHeight = 64;
  static const double _largeTitleHeight = 88;

  const AppBarControl({super.key, required this.control});

  bool get _large => control.getBool("large", false)!;

  double get _toolbarHeight => control.getDouble(
      "toolbar_height", _large ? _largeToolbarHeight : kToolbarHeight)!;

  @override
  Widget build(BuildContext context) {
    debugPrint("AppBar build: ${control.id}");

    var large = _large;
    var title = control.buildTextOrWidget("title");
    var foregroundColor = control.getColor("color", context);
    var titleTextStyle = control.getTextStyle(
        "title_text_style", materialStyleTheme(Theme.of(context)));

    var appBar = AppBar(
      leading: control.buildWidget("leading"),
      leadingWidth: control.getDouble("leading_width"),
      automaticallyImplyLeading:
          control.getBool("automatically_imply_leading", true)!,
      title: large ? null : title,
      bottom: large
          ? _largeTitle(context, title, foregroundColor, titleTextStyle)
          : null,
      centerTitle: control.getBool("center_title"),
      toolbarHeight: _toolbarHeight,
      foregroundColor: foregroundColor,
      backgroundColor: control.getColor("bgcolor", context),
      elevation: control.getDouble("elevation"),
      actions: control.buildWidgets("actions"),
      systemOverlayStyle: Theme.of(context)
          .extension<SystemUiOverlayStyleTheme>()
          ?.systemUiOverlayStyle,
      shadowColor: control.getColor("shadow_color", context),
      scrolledUnderElevation: control.getDouble("elevation_on_scroll"),
      forceMaterialTransparency:
          control.getBool("force_material_transparency", false)!,
      primary: !control.getBool("secondary", false)!,
      titleSpacing: control.getDouble("title_spacing"),
      excludeHeaderSemantics:
          control.getBool("exclude_header_semantics", false)!,
      clipBehavior: control.getClipBehavior("clip_behavior"),
      titleTextStyle: titleTextStyle,
      shape: control.getShape("shape", materialStyleTheme(Theme.of(context))),
      toolbarOpacity: control.getDouble("toolbar_opacity", 1)!,
      toolbarTextStyle:
          control.getTextStyle("toolbar_text_style", materialStyleTheme(Theme.of(context))),
      actionsPadding: control.getPadding("actions_padding"),
    );

    return BaseControl(control: control, child: appBar);
  }

  /// The expanded large title, styled like Flutter's `SliverAppBar.large`.
  PreferredSizeWidget _largeTitle(BuildContext context, Widget? title,
      Color? foregroundColor, TextStyle? titleTextStyle) {
    var theme = Theme.of(context);
    var appBarTheme = AppBarTheme.of(context);
    var style = titleTextStyle ??
        appBarTheme.titleTextStyle ??
        theme.textTheme.headlineMedium?.copyWith(
            color: foregroundColor ??
                appBarTheme.foregroundColor ??
                (theme.useMaterial3 ||
                        theme.colorScheme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onPrimary));

    return PreferredSize(
      preferredSize: const Size.fromHeight(_largeTitleHeight),
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 28),
          child: DefaultTextStyle(
            style: style ?? const TextStyle(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: title ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (_large ? _largeTitleHeight : 0));
}
