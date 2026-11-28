#!/usr/bin/env bash
# Advisory (SPEC §6.1, spike S5): features are included by import only. Builds
# the example's core-only and flashlight entries in release mode and checks
# the Dart AOT snapshot for each feature's JNI class and Objective-C names.
#   tool/ruflet_native/check_tree_shaking.sh android|ios
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
platform="${1:-android}"
cd "$here/example"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

snapshot() { # entry -> path of the AOT snapshot
  local entry="$1"
  if [ "$platform" = android ]; then
    flutter build apk --release --target-platform android-arm64 -t "lib/$entry.dart" >/dev/null
    unzip -p build/app/outputs/flutter-apk/app-release.apk lib/arm64-v8a/libapp.so > "$tmp/$entry"
  else
    flutter build ios --release --no-codesign -t "lib/$entry.dart" >/dev/null
    cp build/ios/iphoneos/Runner.app/Frameworks/App.framework/App "$tmp/$entry"
  fi
  echo "$tmp/$entry"
}

# Names only the Flashlight feature's native code uses.
if [ "$platform" = android ]; then
  names=('android/hardware/camera2/CameraManager' 'android.hardware.camera.flash' 'setTorchMode')
else
  names=('AVCaptureDevice' 'defaultDeviceWithMediaType:' 'lockForConfiguration:')
fi

core="$(snapshot core_only)"
with="$(snapshot flashlight_only)"
status=0
for name in "${names[@]}"; do
  in_core="$(strings "$core" | grep -cF -- "$name" || true)"
  in_with="$(strings "$with" | grep -cF -- "$name" || true)"
  echo "$name: core-only=$in_core flashlight=$in_with"
  if [ "$in_core" != 0 ]; then
    echo "::warning::$name is in a core-only $platform build: a feature is not tree-shaken"
    status=1
  fi
done
exit $status
