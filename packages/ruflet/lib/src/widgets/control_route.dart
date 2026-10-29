import 'package:flutter/widgets.dart';

import '../models/control.dart';
import '../utils/numbers.dart';

/// The route each dialog-like control presented, so closing it never pops a
/// route the control does not own.
final _presented = Expando<Route<dynamic>>('Ruflet control route');

/// Presents the route of a dialog-like control (`open: true`).
///
/// Call from `build` when `open` turns true. The route is pushed onto the
/// owning navigator after the frame. If `open` was turned off again before
/// that (or the control left the tree), nothing is pushed and the dismiss
/// lifecycle still completes, so the control can be reopened.
void presentControlRoute(
    BuildContext context, Control control, Route<void> Function() createRoute) {
  control.updateProperties({"_open": true}, python: false);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !control.getBool("open", false)!) {
      debugPrint("${control.type}(${control.id}): closed before presenting.");
      _didDismiss(control);
      return;
    }
    final route = createRoute();
    _presented[control] = route;
    Navigator.of(context).push(route).then((_) {
      if (identical(_presented[control], route)) _presented[control] = null;
      debugPrint("Dismissing ${control.type}(${control.id})");
      _didDismiss(control);
    });
  });
}

/// Closes the route a control presented (`open: false`).
///
/// Call from `build` when `open` turns false. After the frame, only that
/// control's route is closed: popped when it is on top, removed when another
/// route covers it. A close that arrives before the route was pushed is
/// completed by [presentControlRoute]; repeated calls are no-ops.
void closeControlRoute(Control control) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final route = _presented[control];
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  });
}

/// Exactly one `dismiss` per presentation; `open` is reset for Ruby.
void _didDismiss(Control control) {
  control.updateProperties({"_open": false}, python: false);
  control.updateProperties({"open": false});
  control.triggerEvent("dismiss");
}
