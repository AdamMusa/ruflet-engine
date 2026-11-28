#!/usr/bin/env bash
# After an Android build of the example (all features enabled), checks that
# the merged manifest contains every entry of every feature fragment
# (android/features/<feature>.xml) and every entry the replaced plugin merged
# into apps (manifest_parity/<feature>.txt, one entry per line), because
# these entries drive permission requests, package visibility and Play
# device filtering (SPEC §6.2).
#   tool/ruflet_native/check_manifest_parity.sh [debug|release]
#
# A self-test on the same merged manifest runs first, so the check proves
# that it works even while no feature declares entries (flashlight, the only
# feature ported so far, merges none: torch_light 1.1.0's manifest is empty).
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
elements = re.findall(r'<[\w-]+\b[^>]*>', text)

def missing(entry):
    """Whether no element of the merged manifest has the entry's tag and all
    of its android: attributes."""
    attrs = re.findall(r'(android:[\w.]+)="([^"]*)"', entry)
    tag = re.match(r'\s*<([\w-]+)', entry).group(1)
    return not any(re.match(rf'<{tag}\b', m) and all(f'{k}="{v}"' in m for k, v in attrs)
                   for m in elements)

# Self-test: an element of this manifest must be found, and the same element
# with a changed android:name must be reported missing.
probe = next(m for m in elements if re.search(r'android:name="[^"]+"', m))
absent = re.sub(r'android:name="([^"]+)"', r'android:name="\1.ruflet_native_absent"', probe, count=1)
if missing(probe) or not missing(absent):
    print(f'::error::manifest parity self-test failed on {probe}')
    sys.exit(1)

ok = True; checked = 0
sources = [(f, re.findall(r'<[^!?][^>]*?/>', open(f).read(), re.S)) for f in sorted(glob.glob(f'{features}/*.xml'))]
sources += [(f, [l for l in open(f).read().splitlines() if l.strip() and not l.startswith('#')]) for f in sorted(glob.glob(f'{parity}/*.txt'))]
for path, entries in sources:
    for entry in entries:
        checked += 1
        if missing(entry):
            print(f'::error::{os.path.basename(path)}: {entry.strip()} missing from the merged manifest'); ok = False
print(f'manifest parity: {checked} entries checked in {merged} (self-test ok)')
if checked == 0:
    print('::notice::manifest parity: no feature declares manifest entries yet '
          '(android/features/<feature>.xml, manifest_parity/<feature>.txt)')
sys.exit(0 if ok else 1)
PY
