#!/usr/bin/env bash
# Release (Android, R8) smoke run of the example: builds lib/release_smoke.dart
# in release mode, starts it on the device and checks the lines it logs.
#   tool/ruflet_native/release_smoke.sh <android-device-id>
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
device="${1:?usage: release_smoke.sh <android-device-id>}"
cd "$here/example"
flutter build apk --release -t lib/release_smoke.dart
adb -s "$device" install -r build/app/outputs/flutter-apk/app-release.apk >/dev/null
adb -s "$device" logcat -c
adb -s "$device" shell am start -n dev.ruflet.ruflet_native_example/.MainActivity >/dev/null
for _ in $(seq 1 60); do
  if adb -s "$device" logcat -d | grep -q 'RUFLET_NATIVE_SMOKE done'; then break; fi
  sleep 1
done
log="$(adb -s "$device" logcat -d | grep 'RUFLET_NATIVE_SMOKE' || true)"
echo "$log"
adb -s "$device" shell am force-stop dev.ruflet.ruflet_native_example
echo "$log" | grep -q 'RUFLET_NATIVE_SMOKE done' || { echo "::error::smoke run did not finish"; exit 1; }
if echo "$log" | grep -q 'FAILED'; then echo "::error::release smoke failed"; exit 1; fi
