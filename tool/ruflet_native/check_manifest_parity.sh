#!/usr/bin/env bash
# After an Android build of the example (all features enabled), checks that
# the merged manifest contains every entry of every feature fragment
# (android/features/<feature>.xml) and every entry the replaced plugin merged
# into apps (manifest_parity/<feature>.txt, one entry per line), because
# these entries drive permission requests, package visibility and Play
# device filtering (SPEC §6.2).
#   tool/ruflet_native/check_manifest_parity.sh [debug|release]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
variant="${1:-debug}"
merged="$(find "$here/example/build/app/intermediates/merged_manifest" -name AndroidManifest.xml 2>/dev/null | grep "/$variant/" | head -n1)"
if [ -z "$merged" ] || [ ! -f "$merged" ]; then
  echo "::error::no merged manifest for $variant; build the example first"; exit 1
fi
exec python3 - "$merged" "$here/../../packages/ruflet/native/android/features" "$here/manifest_parity" <<'PY'
import glob, os, re, sys
merged, features, parity = sys.argv[1:4]
text = re.sub(r'\s+', ' ', open(merged).read())
def norm(entry): return re.sub(r'\s+', ' ', entry.strip()).replace(' />', '/>').replace('/>', ' />')
ok = True; checked = 0
sources = [(f, re.findall(r'<[^!?][^>]*?/>', open(f).read(), re.S)) for f in sorted(glob.glob(f'{features}/*.xml'))]
sources += [(f, [l for l in open(f).read().splitlines() if l.strip() and not l.startswith('#')]) for f in sorted(glob.glob(f'{parity}/*.txt'))]
for path, entries in sources:
    for entry in entries:
        checked += 1
        attrs = re.findall(r'(android:[\w.]+)="([^"]*)"', entry)
        tag = re.match(r'\s*<([\w-]+)', entry).group(1)
        found = any(all(f'{k}="{v}"' in m for k, v in attrs) for m in re.findall(rf'<{tag}\b[^>]*>', text))
        if not found:
            print(f'::error::{os.path.basename(path)}: {entry.strip()} missing from the merged manifest'); ok = False
print(f'manifest parity: {checked} entries checked in {merged}')
sys.exit(0 if ok else 1)
PY
