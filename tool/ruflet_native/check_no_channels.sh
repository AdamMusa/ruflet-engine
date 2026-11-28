#!/usr/bin/env bash
# Fails when ruflet_native's Dart code uses a platform channel: every native
# call goes over FFI (JNI, the Objective-C runtime, C).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root/packages/ruflet/native"
# Comment lines may name the classes; code may not.
hits="$(grep -rnE '\b(MethodChannel|EventChannel|BasicMessageChannel|OptionalMethodChannel|BinaryMessenger)\b' lib |
  grep -vE '^[^:]+:[0-9]+:\s*//' || true)"
if [ -n "$hits" ]; then
  echo "::error::platform channels are not allowed in ruflet_native:"
  echo "$hits"
  exit 1
fi
echo "no platform channels in packages/ruflet/native/lib"
