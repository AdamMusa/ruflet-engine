import 'package:flutter/material.dart';

import '../utils/box.dart' show parseBoxConstraints;
import '../utils/buttons.dart' show parseButtonStyle;
import '../utils/theme.dart' show parseVisualDensity;
import 'icon_button_core.dart';

/// Material skin of [IconButtonCore]: maps the core's values onto
/// IconButton (standard, filled, filled tonal or outlined).
class MaterialIconButtonSkin extends StatelessWidget {
  const MaterialIconButtonSkin({super.key, required this.core});

  final IconButtonCore core;

  /// A Ruby icon gets the colour on the Icon itself (as before); a child
  /// control icon inherits it.
  static Widget? _colored(Widget? icon, Color? color) => switch (icon) {
        null => null,
        _ when color == null => icon,
        Icon() => Icon(icon.icon, color: color),
        _ => IconTheme.merge(data: IconThemeData(color: color), child: icon),
      };

  @override
  Widget build(BuildContext context) {
    final p = core.props;
    // Without an icon the native button stays (empty), as on iOS.
    final icon = _colored(p.icon, p.iconColor) ?? const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = parseButtonStyle(p.style.value, theme,
        defaultForegroundColor: theme.colorScheme.primary,
        defaultBackgroundColor: Colors.transparent,
        defaultOverlayColor: Colors.transparent,
        defaultShadowColor: Colors.transparent,
        defaultSurfaceTintColor: Colors.transparent,
        defaultElevation: 0,
        defaultPadding: const EdgeInsets.all(8),
        defaultBorderSide: BorderSide.none,
        defaultShape: theme.useMaterial3
            ? const StadiumBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)));
    final selectedIcon = _colored(p.selectedIcon, p.selectedIconColor);
    final constraints = parseBoxConstraints(p.sizeConstraints.value);
    final visualDensity = parseVisualDensity(p.visualDensity.string);
    final enableFeedback = p.enableFeedback ?? true;

    return switch (core.variant) {
      IconButtonVariant.filled => IconButton.filled(
          autofocus: p.autofocus,
          focusNode: core.focusNode,
          highlightColor: p.highlightColor,
          disabledColor: p.disabledColor,
          hoverColor: p.hoverColor,
          enableFeedback: enableFeedback,
          padding: p.padding,
          alignment: p.alignment,
          focusColor: p.focusColor,
          splashColor: p.splashColor,
          splashRadius: p.splashRadius,
          icon: icon,
          iconSize: p.iconSize,
          mouseCursor: p.mouseCursor,
          style: style,
          isSelected: p.selected,
          constraints: constraints,
          visualDensity: visualDensity,
          onLongPress: core.onLongPress,
          selectedIcon: selectedIcon,
          onPressed: core.onClick),
      IconButtonVariant.tonal => IconButton.filledTonal(
          autofocus: p.autofocus,
          focusNode: core.focusNode,
          highlightColor: p.highlightColor,
          disabledColor: p.disabledColor,
          hoverColor: p.hoverColor,
          enableFeedback: enableFeedback,
          padding: p.padding,
          alignment: p.alignment,
          focusColor: p.focusColor,
          splashColor: p.splashColor,
          splashRadius: p.splashRadius,
          icon: icon,
          iconSize: p.iconSize,
          mouseCursor: p.mouseCursor,
          style: style,
          isSelected: p.selected,
          constraints: constraints,
          visualDensity: visualDensity,
          onLongPress: core.onLongPress,
          selectedIcon: selectedIcon,
          onPressed: core.onClick),
      IconButtonVariant.outlined => IconButton.outlined(
          autofocus: p.autofocus,
          focusNode: core.focusNode,
          highlightColor: p.highlightColor,
          disabledColor: p.disabledColor,
          hoverColor: p.hoverColor,
          enableFeedback: enableFeedback,
          padding: p.padding,
          alignment: p.alignment,
          focusColor: p.focusColor,
          splashColor: p.splashColor,
          splashRadius: p.splashRadius,
          icon: icon,
          iconSize: p.iconSize,
          mouseCursor: p.mouseCursor,
          style: style,
          isSelected: p.selected,
          constraints: constraints,
          visualDensity: visualDensity,
          onLongPress: core.onLongPress,
          selectedIcon: selectedIcon,
          onPressed: core.onClick),
      IconButtonVariant.standard => IconButton(
          autofocus: p.autofocus,
          focusNode: core.focusNode,
          highlightColor: p.highlightColor,
          disabledColor: p.disabledColor,
          hoverColor: p.hoverColor,
          enableFeedback: enableFeedback,
          padding: p.padding,
          alignment: p.alignment,
          focusColor: p.focusColor,
          splashColor: p.splashColor,
          splashRadius: p.splashRadius,
          icon: icon,
          iconSize: p.iconSize,
          mouseCursor: p.mouseCursor,
          style: style,
          isSelected: p.selected,
          constraints: constraints,
          visualDensity: visualDensity,
          onLongPress: core.onLongPress,
          selectedIcon: selectedIcon,
          onPressed: core.onClick),
    };
  }
}
