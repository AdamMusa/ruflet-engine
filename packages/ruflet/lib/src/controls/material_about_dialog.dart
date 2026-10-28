import 'package:flutter/material.dart';

import '../extensions/control.dart';
import '../models/control.dart';
import '../utils/numbers.dart';
import '../widgets/control_inherited_notifier.dart';
import '../widgets/material_dialog_route.dart';

/// The route each AboutDialog control presented, so `open: false` closes
/// exactly what it opened.
final _presented = Expando<Route<void>>('AboutDialog route');

/// Material renderer of `AboutDialog`: the SDK [AboutDialog] (with its
/// built-in "View licenses" button) or, with `view: "licenses"`, the SDK
/// [LicensePage] directly.
class MaterialAboutDialogControl extends StatelessWidget {
  final Control control;

  const MaterialAboutDialogControl({super.key, required this.control});

  bool get _licensesOnly =>
      control.getString("view", "about")!.toLowerCase() == "licenses";

  Widget _live(WidgetBuilder builder) {
    return ControlInheritedNotifier(
      notifier: control,
      child: Builder(builder: (context) {
        ControlInheritedNotifier.of(context);
        return builder(context);
      }),
    );
  }

  Route<void> _createRoute(BuildContext context) {
    if (_licensesOnly) {
      return MaterialPageRoute<void>(
        builder: (_) => _live((context) => LicensePage(
              applicationName: control.getString("application_name"),
              applicationVersion: control.getString("application_version"),
              applicationIcon: control.buildIconOrWidget("application_icon"),
              applicationLegalese: control.getString("application_legalese"),
            )),
      );
    }
    return ControlMaterialDialogRoute<void>(
      control: control,
      context: context,
      barrierDismissible: !control.getBool("modal", false)!,
      builder: (_) => _live((context) => SafeArea(
            child: AboutDialog(
              applicationName: control.getString("application_name"),
              applicationVersion: control.getString("application_version"),
              applicationIcon: control.buildIconOrWidget("application_icon"),
              applicationLegalese: control.getString("application_legalese"),
              children: control.buildWidgets("controls"),
            ),
          )),
    );
  }

  void _present(BuildContext context) {
    if (!context.mounted || !control.getBool("open", false)!) {
      _didDismiss();
      return;
    }
    final route = _createRoute(context);
    _presented[control] = route;
    Navigator.of(context).push(route).then((_) {
      if (identical(_presented[control], route)) _presented[control] = null;
      _didDismiss();
    });
  }

  void _didDismiss() {
    control.updateProperties({"_open": false}, python: false);
    control.updateProperties({"open": false});
    control.triggerEvent("dismiss");
  }

  /// Closes [route] and the pageless routes opened from it (the license
  /// pages); app views pushed above it are left alone.
  static void _close(Route<void>? route) {
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    Route<dynamic>? top;
    navigator.popUntil((candidate) {
      top = candidate;
      return candidate == route || candidate.settings is Page;
    });
    if (identical(top, route)) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("AboutDialog build: ${control.id}");

    final open = control.getBool("open", false)!;
    final lastOpen = control.getBool("_open", false)!;

    if (open && !lastOpen) {
      control.updateProperties({"_open": true}, python: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _present(context));
    } else if (!open && lastOpen) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _close(_presented[control]));
    }
    return const SizedBox.shrink();
  }
}
