#!/usr/bin/env bash
# Fails when ruflet_native's Dart code uses a platform channel: every native
# call goes over FFI (JNI, the Objective-C runtime, C). Covers the channel
# classes, Flutter's own channels (SystemChannels), any binary messenger
# (BinaryMessenger, defaultBinaryMessenger, binaryMessenger:) and raw
# platform messages. Flutter's high-level services (Clipboard, HapticFeedback)
# stay allowed. Keep the pattern equal to
# packages/ruflet/native/test/gates_test.dart.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root/packages/ruflet/native"
# Comment lines may name the classes; code may not.
hits="$(grep -rnE '\b(MethodChannel|EventChannel|BasicMessageChannel|OptionalMethodChannel|SystemChannels|sendPlatformMessage|setMessageHandler|channelBuffers)\b|[Bb]inaryMessenger' lib |
  grep -vE '^[^:]+:[0-9]+:\s*//' || true)"
if [ -n "$hits" ]; then
  echo "::error::platform channels are not allowed in ruflet_native:"
  echo "$hits"
  exit 1
fi
echo "no platform channels in packages/ruflet/native/lib"
