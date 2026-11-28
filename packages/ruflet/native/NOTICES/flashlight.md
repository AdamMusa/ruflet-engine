# flashlight

`lib/src/flashlight/` reproduces the behavior, the error messages and the
exception classes (names and `toString()`) of:

- **torch_light 1.1.0** (https://pub.dev/packages/torch_light,
  https://github.com/svprdga/torch_light), by David Serrano Canales:
  `lib/torch_light.dart`, `lib/exceptions.dart`,
  `android/src/main/kotlin/com/svprdga/torchlight/TorchLightPlugin.kt`,
  `ios/Classes/SwiftTorchLightPlugin.swift`.
  Licensed under the Apache License, Version 2.0
  (https://www.apache.org/licenses/LICENSE-2.0). The package ships the
  license text without a separate copyright line.

The Dart code is ruflet_flashlight's (ruflet-engine#136, merged in
5a314c9f), copied unchanged except for import paths. No torch_light source
file is included: the platform calls are made from Dart over JNI and the
Objective-C runtime.
