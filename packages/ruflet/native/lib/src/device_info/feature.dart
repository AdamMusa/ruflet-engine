import '../feature.dart';

/// Device info (platform mechanism: DeviceInfoPlatform, for Page.get_device_info and the android_tv check; device_info_plus today).
///
/// Inert stub created by PR 1: it claims no control type and installs
/// nothing, so the core (or the wrapper package) keeps serving it. The
/// feature's own PR replaces this file and fills this folder.
const deviceInfoFeature = NativeFeature(name: 'device_info');
