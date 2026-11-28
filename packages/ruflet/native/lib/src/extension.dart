import 'package:flutter/widgets.dart';
import 'package:ruflet/ruflet.dart';

import 'feature.dart';
import 'ffi/runtime.dart';
import 'glue/platform.dart';
import 'registry.dart';

/// Ruflet's native services on Android and iOS, over FFI.
///
/// Register it before the core, as every extension is:
/// ```dart
/// import 'package:ruflet_native/ruflet_native.dart' show RufletNativeExtension;
/// ...
///   RufletNativeExtension(),
/// ```
/// `RufletNativeExtension()` serves the core features. Each extension
/// feature has its own entry library (for example
/// `package:ruflet_native/flashlight.dart`) whose `Extension` serves only that
/// feature, so an app carries only what it registers.
///
/// The control types, method names, arguments, replies, events and error
/// texts are the ones the core and extension services have today: only the
/// code under them changes.
class RufletNativeExtension extends RufletExtension {
  /// The core features.
  RufletNativeExtension() : this.features(coreFeatures);

  /// The given [features]. A wrapper package passes its current service
  /// ([offPlatformService]) and widget ([offPlatformWidget]) for the platforms
  /// where a feature with [OffPlatform.wrapper] does not run.
  RufletNativeExtension.features(this.features,
      {this.offPlatformService, this.offPlatformWidget});

  /// The features this extension serves.
  final List<NativeFeature> features;

  /// The wrapper's own service off Android/iOS ([OffPlatform.wrapper]).
  final RufletService? Function(Control control)? offPlatformService;

  /// The wrapper's own widget off Android/iOS ([OffPlatform.wrapper]).
  final Widget? Function(Key? key, Control control)? offPlatformWidget;

  // Shared by every instance: install runs once per process (and again after
  // a hot restart, which resets statics and the plugin registrant).
  static final Set<String> _installed = {};

  /// The feature serving [type] in this extension, or null.
  NativeFeature? featureFor(String type) {
    for (final feature in features) {
      if (feature.controlTypes.contains(type)) return feature;
    }
    return null;
  }

  /// Installs the platform-mechanism features (FFI implementations of the
  /// replaced plugins' platform interfaces) on Android and iOS. The template
  /// calls this before `runApp`, after Flutter's generated plugin registrant
  /// set the old default instances, so the FFI instances win.
  @override
  void ensureInitialized() {
    if (!isNativeTarget) return;
    for (final feature in features) {
      final install = feature.install;
      if (install == null || !_installed.add(feature.name)) continue;
      ensureNativeRuntime();
      install();
    }
  }

  @override
  RufletService? createService(Control control) {
    final feature = featureFor(control.type);
    final create = feature?.createService;
    if (feature == null || create == null) return null;
    if (isNativeTarget) {
      ensureNativeRuntime();
      return create(control);
    }
    return switch (feature.offPlatform) {
      OffPlatform.delegate => null,
      OffPlatform.self => create(control),
      OffPlatform.wrapper => offPlatformService?.call(control),
    };
  }

  @override
  Widget? createWidget(Key? key, Control control) {
    final feature = featureFor(control.type);
    final create = feature?.createWidget;
    if (feature == null || create == null) return null;
    if (isNativeTarget) {
      ensureNativeRuntime();
      return create(key, control);
    }
    return switch (feature.offPlatform) {
      OffPlatform.delegate => null,
      OffPlatform.self => create(key, control),
      OffPlatform.wrapper => offPlatformWidget?.call(key, control),
    };
  }

  /// Handles a native service call that has no mounted service control
  /// (FilePicker `pick_files` client action, TextField paste-files). Returns
  /// null when not handled. The core calls it once its additive hook exists
  /// (owner question Q7); until then nothing calls it.
  // Becomes an override of RufletExtension.invokeWithoutService once the
  // core hook lands; annotate it then.
  // ignore: annotate_overrides
  Future<Object?>? invokeWithoutService(
      String type, String method, Map<String, Object?> args) {
    if (!isNativeTarget) return null;
    for (final feature in features) {
      final invoke = feature.invokeWithoutService;
      if (invoke == null) continue;
      final result = invoke(type, method, args);
      if (result != null) {
        ensureNativeRuntime();
        return result;
      }
    }
    return null;
  }
}
