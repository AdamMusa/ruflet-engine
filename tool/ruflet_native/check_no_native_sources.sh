#!/usr/bin/env bash
# Fails on any hand-written native source file in ruflet_native or its
# committed tooling. Everything is Dart calling the platform over FFI; only
# build configuration (Gradle, manifest fragments, ProGuard rules, podspec,
# plists, resources) is allowed. The generated host folders of the dev apps
# (android/, ios/, web/ from prepare_example.sh) are not committed and are
# skipped.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
found="$(git ls-files --cached --others --exclude-standard packages/ruflet/native tool/ruflet_native |
  grep -E '\.(java|kt|kts|m|mm|h|hpp|c|cc|cpp|cxx|swift|s|S|asm)$' || true)"
if [ -n "$found" ]; then
  echo "::error::native source files are not allowed in ruflet_native (FFI only):"
  echo "$found"
  exit 1
fi
echo "no native source files in packages/ruflet/native and tool/ruflet_native"
