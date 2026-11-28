# Flashlight parity

Known differences from ruflet_flashlight with torch_light 1.1.0: none.

- Replies and error texts are torch_light's, byte for byte: the fixtures in
  `test/fixtures/flashlight/` were recorded from the old plugin on an iPhone 17
  Pro Max simulator (iOS 26.0) and an Android 15 emulator (API 35, arm64) and
  are replayed against this feature on the same devices
  (`tool/ruflet_native/example/integration_test/flashlight_test.dart`) and on
  the host with the recorded native outcomes (`test/flashlight/fixture_test.dart`).
- The camera id is looked up on first use instead of when the engine attaches
  (torch_light's `onAttachedToEngine`). Both catch any failure and then answer
  "Torch is not available"; only an app that gains camera access between engine
  start and the first call could see a difference.
- torch_light's iOS code sent a second reply after a failed
  `lockForConfiguration` (`result(FlutterError)` then `result(nil)`); the
  channel kept the first, which is what this feature throws.
