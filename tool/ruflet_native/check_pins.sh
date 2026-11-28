#!/usr/bin/env bash
# The FFI packages stay inside the ranges proven on the pinned Flutter, and
# the platform interfaces equal what the core resolves (a newer interface may
# add abstract members). Run after `flutter pub get` in packages/ruflet.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "$root" <<'PY'
import re, sys
root = sys.argv[1]
pubspec = open(f'{root}/packages/ruflet/native/pubspec.yaml').read()
def constraint(name):
    m = re.search(rf"^  {name}:\s*'?([^'\n#]+?)'?\s*(#.*)?$", pubspec, re.M)
    return m.group(1).strip() if m else None
ok = True
proven = {'jni': '>=1.2.1 <1.3.0', 'jni_flutter': '>=1.1.0 <1.2.0', 'objective_c': '>=9.5.0 <9.6.0'}
for name, want in proven.items():
    got = constraint(name)
    if got != want:
        print(f'::error::{name} must stay {want!r} (got {got!r}); widen it only with the latest-stable job'); ok = False
    else:
        print(f'ok {name} {got}')
lock = open(f'{root}/packages/ruflet/pubspec.lock').read()
def resolved(name):
    m = re.search(rf'\n  {name}:\n(?:    .*\n)*?    version: "([^"]+)"', lock)
    return m.group(1) if m else None
for name in ['url_launcher_platform_interface', 'share_plus_platform_interface', 'device_info_plus_platform_interface']:
    got, core = constraint(name), resolved(name)
    if got != core:
        print(f'::error::{name} is pinned to {got} but the core resolves {core}'); ok = False
    else:
        print(f'ok {name} {got} == core')
sys.exit(0 if ok else 1)
PY
