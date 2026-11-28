#!/usr/bin/env bash
# Fails on any hand-written native source file, and on any prebuilt native
# binary or library (jar, aar, so, a, dylib, framework, jniLibs/), in
# ruflet_native or its committed tooling. Everything is Dart calling the
# platform over FFI; only build configuration (Gradle, manifest fragments,
# ProGuard rules, podspec, plists, resources) is allowed. The generated host
# folders of the dev apps (android/, ios/, web/ from prepare_example.sh) are
# not committed and are skipped. Keep the patterns equal to
# packages/ruflet/native/test/gates_test.dart.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
found="$(git ls-files --cached --others --exclude-standard packages/ruflet/native tool/ruflet_native |
  grep -E '\.(java|kt|kts|groovy|scala|m|mm|h|hh|hpp|hxx|c|cc|cpp|cxx|swift|s|S|asm|rs|go|zig|jar|aar|class|dex|so|a|o|dylib|dll|lib|tbd)$|(^|/)(jniLibs|[^/]+\.(xc)?framework)/|(^|/)(CMakeLists\.txt|Makefile|Cargo\.toml|Package\.swift)$' || true)"
if [ -n "$found" ]; then
  echo "::error::native sources and prebuilt native binaries are not allowed in ruflet_native (FFI only):"
  echo "$found"
  exit 1
fi
echo "no native sources or binaries in packages/ruflet/native and tool/ruflet_native"
