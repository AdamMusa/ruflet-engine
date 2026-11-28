# Flashlight parity

Known differences from ruflet_flashlight with torch_light 1.1.0 in what Ruby
sees: none.

- The code is ruflet_flashlight's as ruflet-engine#136 merged it (5a314c9f),
  copied verbatim except for import paths; `check_glue_drift.sh` diffs every
  file of this folder that names a source against it.
- Replies and error texts are torch_light's, byte for byte: the fixtures in
  `test/fixtures/flashlight/` were recorded from the old plugin on an iPhone 17
  Pro Max simulator (iOS 26.0) and an Android 15 emulator (API 35, arm64) and
  are replayed against this feature on the same devices
  (`tool/ruflet_native/example/integration_test/flashlight_test.dart`) and on
  the host with the recorded native outcomes (`test/flashlight/fixture_test.dart`).
  `test/flashlight/android_torch_test.dart` and `ios_torch_test.dart` run every
  branch, including the Android error branches no emulator reaches.
- The camera id is looked up on first use instead of when the engine attaches
  (torch_light's `onAttachedToEngine`). Both catch any failure and then answer
  "Torch is not available"; only an app that gains camera access between engine
  start and the first call could see a difference. The failure is logged with
  `debugPrint` and its cause, where torch_light wrote `Log.d` (tag
  `torch_light_plugin`) without one.
- `is_available` turns a Java exception into `EnableTorchException` with the
  exception's `getMessage()`, which is what torch_light's Dart side made of
  the error its platform channel replied. A `java.lang.Error` from
  `setTorchMode`, which torch_light's channel did not catch (the app
  crashed), is replied with its text.
- torch_light's iOS code sent a second reply after a failed
  `lockForConfiguration` (`result(FlutterError)` then `result(nil)`); the
  channel kept the first, which is what this feature throws.
