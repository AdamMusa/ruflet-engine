import '../feature.dart';

/// Sensors (core services `Accelerometer`, `UserAccelerometer`, `Gyroscope`, `Magnetometer`, `Barometer`; sensors_plus today).
///
/// Inert stub created by PR 1: it claims no control type and installs
/// nothing, so the core (or the wrapper package) keeps serving it. The
/// feature's own PR replaces this file and fills this folder.
const sensorsFeature = NativeFeature(name: 'sensors');
