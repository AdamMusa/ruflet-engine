# ruflet_native

Ruflet's native services on Android and iOS in one Flutter plugin, built only
on FFI: the plugin's code is Dart calling the platform directly through
package:jni (JNI) on Android and package:objective_c (the Objective-C runtime)
plus dart:ffi (C) on iOS. It has no Java, Kotlin, Objective-C, Swift or C file
and no platform channel; `android/` and `ios/` hold build configuration only.

Ruflet itself does not change: the Ruby API, the protocol, the transport and
every control type, method, argument, reply, event and error text stay as they
are. The plugin plugs in at the Dart `RufletService` level, under the same
control types the core and the `ruflet_<feature>` packages serve today.

## Use

```dart
import 'package:ruflet_native/ruflet_native.dart' show RufletNativeExtension;

final extensions = <RufletExtension>[
  RufletNativeExtension(), // the core features
  // ...
];
```

Extension features have their own entry library (for example
`package:ruflet_native/flashlight.dart`, whose `Extension` serves only
Flashlight), so an app carries only the features it registers: Dart AOT tree
shaking drops the rest, with their JNI class and Objective-C selector names.
Off Android and iOS a feature delegates to the core (core features), answers
what the old extension answered (`OffPlatform.self`), or uses the wrapper
package's fallback (`OffPlatform.wrapper`).

## Status

| Feature | Status |
|---|---|
| flashlight | implemented (from ruflet-engine#136), fixtures recorded on iOS and Android |
| every other planned feature | inert stub (`lib/src/<feature>/feature.dart`): the core or the wrapper keeps serving it |

Nothing reaches users yet: no app registers the plugin until the switch
(template PR).

## Layout

- `lib/src/extension.dart`, `feature.dart`, `registry.dart`: the extension, the
  feature description and the complete registry.
- `lib/src/glue/`: platform gate, `NativeStream`, error builders.
- `lib/src/ffi/`: the shared FFI layer (frozen after PR 1). `android/`: context,
  activity per call, main Looper/Handler/Executor, the single plugin proxy
  (`ActivityBinding`), poller, serial worker, Java error helpers, jnigen
  bindings. `ios/`: lazy frameworks, typed `objc_msgSend`, synchronous blocks and
  delegates, `AsyncBlock` for callbacks from the run loop or other threads,
  notifications, view controllers, Info.plist guard, serial worker, libSystem and
  dispatch.
- `lib/src/<feature>/`: one folder per feature.
- `android/build.gradle`: per-feature Gradle dependencies, manifest fragments and
  ProGuard rules, found by file name under `android/features/`.
- `ios/`: a resource-only pod shipping `PrivacyInfo.xcprivacy`.
- `test/`: host tests and the recorded fixtures (`test/fixtures/<feature>/`).

Development tooling (example app, fixture recorder, wire harness, binding
generators, CI checks) lives in `tool/ruflet_native/` at the engine root and is
not part of this package.

## Threading rules learned in wave 0

- Android: package:jni runs Dart-implemented Java methods inline on the main
  thread. Such a callback runs outside any Flutter task, so each entry ends with
  `wakeEventLoop()`; otherwise futures it completes wait for the next UI task.
- iOS: an isolate-local callback (a `Pointer.fromFunction` block or a
  `NativeCallable.isolateLocal` method) that the main run loop calls outside a
  Dart task aborts the process on Flutter 3.41.2. Such callbacks use
  `AsyncBlock` (`NativeCallable.isolateGroupBound` that retains its arguments and
  posts them to the root isolate). `MainThreadBlock` and `DartDelegate` are for
  callbacks made synchronously during a Dart call.
