# tool/ruflet_native

Development tooling for `packages/ruflet/native` (package `ruflet_native`).
Nothing here is synced into the template or shipped to apps.

| Path | What |
|---|---|
| `prepare_example.sh [example\|fixture_recorder] [--cocoapods\|--swiftpm] [--web]` | generates the dev apps' host folders with `flutter create` (never committed: they would be native sources) and their `pubspec.yaml` from `pubspec.base.yaml`, applies the template's iOS settings and the per-feature `patches/*`, copies the fixtures into the example |
| `example/` | runs the integration tests: `flutter test integration_test -d <device>` (fixture replays, shared FFI layers); `lib/release_smoke.dart`, `lib/core_only.dart`, `lib/flashlight_only.dart`, `lib/all_features.dart` are probes |
| `fixture_recorder/` | records fixtures from the OLD plugins: `flutter drive --driver=test_driver/record_driver.dart --target=integration_test/<feature>_record_test.dart -d <device>` writes `packages/ruflet/native/test/fixtures/<feature>/<platform>.json`; `deps/<feature>.yaml` adds the old package |
| `wire_harness/` | `ruflet_native_wire`: a real `RufletBackend` with an in-memory transport, the fixture format and the comparison |
| `bindings/` | jnigen 0.16 configs: `dart run generate.dart` (needs one `flutter build apk --release` of the example for the classpath) |
| `check_*.sh` | CI gates: no native sources, no channels, glue drift, privacy manifest, pins, manifest parity, tree shaking |
| `release_smoke.sh <device>` | release (R8) smoke run on Android |

A feature PR adds only its own files: `example/integration_test/<feature>_test.dart`,
`example/patches/<feature>.*`, `fixture_recorder/integration_test/<feature>_record_test.dart`,
`fixture_recorder/deps/<feature>.yaml`, `bindings/<feature>.yaml` and
`manifest_parity/<feature>.txt`.
