import 'package:flutter/widgets.dart';

import '../models/control.dart';
import 'numbers.dart';
import 'widget_state.dart';

/// The width a side gets when the map does not name it: the map's `all`
/// value (Ruby's `{"all" => 8}` shorthand), else 0.
double _unnamedSide(dynamic value) =>
    value is Map ? parseDouble(value['all'], 0)! : 0;

/// The width every side gets when [value] is not a map: a number, or a
/// finite numeric string such as `"10"` (an HTML attribute). Null when
/// [value] has no such reading.
double? _everySide(dynamic value) {
  if (value is int || value is double) return parseDouble(value, 0)!;
  if (value is String) {
    final side = double.tryParse(value.trim());
    if (side != null && side.isFinite) return side;
  }
  return null;
}

/// Edge insets are a number (all sides), a `left/top/right/bottom` map, or
/// an `{all: n}` map; in a map, `all` fills the sides it does not name. A
/// numeric string reads like the number; any other value that is not a map
/// gives [defaultValue].
EdgeInsets? parseEdgeInsets(dynamic value, [EdgeInsets? defaultValue]) {
  if (value == null) return defaultValue;
  if (value is! Map) {
    final side = _everySide(value);
    return side == null ? defaultValue : EdgeInsets.all(side);
  }
  final all = _unnamedSide(value);
  return EdgeInsets.fromLTRB(
      parseDouble(value['left'], all)!,
      parseDouble(value['top'], all)!,
      parseDouble(value['right'], all)!,
      parseDouble(value['bottom'], all)!);
}

EdgeInsets? parseMargin(dynamic value, [EdgeInsets? defaultValue]) {
  return parseEdgeInsets(value, defaultValue);
}

EdgeInsets? parsePadding(dynamic value, [EdgeInsets? defaultValue]) {
  return parseEdgeInsets(value, defaultValue);
}

EdgeInsetsDirectional? parseEdgeInsetsDirectional(dynamic value,
    [EdgeInsetsDirectional? defaultValue]) {
  if (value == null) return defaultValue;
  if (value is! Map) {
    final side = _everySide(value);
    return side == null ? defaultValue : EdgeInsetsDirectional.all(side);
  }
  final all = _unnamedSide(value);
  return EdgeInsetsDirectional.fromSTEB(
      parseDouble(value['left'], all)!,
      parseDouble(value['top'], all)!,
      parseDouble(value['right'], all)!,
      parseDouble(value['bottom'], all)!);
}

WidgetStateProperty<EdgeInsets?>? parseWidgetStateEdgeInsets(dynamic value,
    {EdgeInsets? defaultEdgeInsets,
    WidgetStateProperty<EdgeInsets?>? defaultValue}) {
  if (value == null) return defaultValue;

  return getWidgetStateProperty<EdgeInsets?>(
      value, (jv) => parseEdgeInsets(jv), defaultEdgeInsets);
}

WidgetStateProperty<EdgeInsets?>? parseWidgetStatePadding(dynamic value,
    {EdgeInsets? defaultPadding,
    WidgetStateProperty<EdgeInsets?>? defaultValue}) {
  return parseWidgetStateEdgeInsets(value,
      defaultEdgeInsets: defaultPadding, defaultValue: defaultValue);
}

WidgetStateProperty<EdgeInsets?>? parseWidgetStateMargin(dynamic value,
    {EdgeInsets? defaultEdgeInsets,
    WidgetStateProperty<EdgeInsets?>? defaultValue}) {
  return parseWidgetStateEdgeInsets(value,
      defaultEdgeInsets: defaultEdgeInsets, defaultValue: defaultValue);
}

extension EdgeInsetsParsers on Control {
  EdgeInsets? getEdgeInsets(String propertyName, [EdgeInsets? defaultValue]) {
    return parseEdgeInsets(get(propertyName), defaultValue);
  }

  EdgeInsets? getMargin(String propertyName, [EdgeInsets? defaultValue]) {
    return parseMargin(get(propertyName), defaultValue);
  }

  EdgeInsets? getPadding(String propertyName, [EdgeInsets? defaultValue]) {
    return parsePadding(get(propertyName), defaultValue);
  }

  EdgeInsetsDirectional? getEdgeInsetsDirectional(String propertyName,
      [EdgeInsetsDirectional? defaultValue]) {
    return parseEdgeInsetsDirectional(get(propertyName), defaultValue);
  }

  WidgetStateProperty<EdgeInsets?>? getWidgetStateEdgeInsets(
      String propertyName,
      {EdgeInsets? defaultEdgeInsets,
      WidgetStateProperty<EdgeInsets?>? defaultValue}) {
    return parseWidgetStateEdgeInsets(get(propertyName),
        defaultEdgeInsets: defaultEdgeInsets, defaultValue: defaultValue);
  }

  WidgetStateProperty<EdgeInsets?>? getWidgetStatePadding(String propertyName,
      {EdgeInsets? defaultPadding,
      WidgetStateProperty<EdgeInsets?>? defaultValue}) {
    return parseWidgetStatePadding(get(propertyName),
        defaultPadding: defaultPadding, defaultValue: defaultValue);
  }

  WidgetStateProperty<EdgeInsets?>? getWidgetStateMargin(String propertyName,
      {EdgeInsets? defaultEdgeInsets,
      WidgetStateProperty<EdgeInsets?>? defaultValue}) {
    return parseWidgetStateMargin(get(propertyName),
        defaultEdgeInsets: defaultEdgeInsets, defaultValue: defaultValue);
  }
}
