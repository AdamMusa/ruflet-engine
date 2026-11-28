import 'package:flutter/widgets.dart';
import 'package:ruflet/ruflet.dart';

/// What a feature does off Android and iOS (desktop, web, tests on a host).
enum OffPlatform {
  /// [RufletNativeExtension] returns null, so the next extension (in the end
  /// the core) handles the control exactly as today. Every core feature.
  delegate,

  /// The feature's own glue answers what the old extension answered on that
  /// platform (for example Flashlight's "supported only on Android and iOS
  /// devices" error).
  self,

  /// The wrapper package's fallback (its current service or widget, with its
  /// desktop/web plugins) answers. [RufletNativeExtension.features] takes the
  /// fallback factories.
  wrapper,
}

/// One native service of the plugin: which control types it serves and how.
///
/// Every planned feature has a constant of this class in
/// `lib/src/<feature>/feature.dart`. An inert stub claims no control type and
/// installs nothing, so the registry can list every feature from the start.
@immutable
class NativeFeature {
  const NativeFeature({
    required this.name,
    this.controlTypes = const {},
    this.offPlatform = OffPlatform.delegate,
    this.createService,
    this.createWidget,
    this.install,
    this.invokeWithoutService,
  });

  /// The feature name, e.g. `battery`. Also the Android feature file name
  /// (`android/features/<name>.*`) and, for an extension feature, the suffix
  /// of its wrapper package (`ruflet_<name>`).
  final String name;

  /// The Ruflet control types this feature serves, e.g. `{'Battery'}`.
  /// Empty for platform-only features (url_launcher, share, device_info) and
  /// for inert stubs.
  final Set<String> controlTypes;

  /// What happens off Android and iOS.
  final OffPlatform offPlatform;

  /// Mechanism "service": the feature's RufletService for [controlTypes].
  final RufletService Function(Control control)? createService;

  /// The widget for a control type that renders (camera, qrcode_scanner,
  /// video).
  final Widget Function(Key? key, Control control)? createWidget;

  /// Mechanism "platform": installs the FFI implementation of the replaced
  /// plugin's pure-Dart platform interface. Called once per process on
  /// Android and iOS, from [RufletExtension.ensureInitialized].
  final void Function()? install;

  /// Answers a native call that has no mounted service control (the core
  /// hook, owner question Q7). Returns null when not handled.
  final Future<Object?>? Function(
      String type, String method, Map<String, Object?> args)? invokeWithoutService;

  /// Whether this feature is still an inert stub.
  bool get isStub =>
      controlTypes.isEmpty &&
      createService == null &&
      createWidget == null &&
      install == null &&
      invokeWithoutService == null;

  @override
  String toString() => 'NativeFeature($name)';
}
