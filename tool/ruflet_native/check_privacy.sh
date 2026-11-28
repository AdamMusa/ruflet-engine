#!/usr/bin/env bash
# Keeps ios/Resources/PrivacyInfo.xcprivacy in step with ruflet_native's
# Dart code: a required-reason API category used by the code must be
# declared, with a reason (SPEC §6.3). The manifest must also parse and
# declare no tracking.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 - "$root/packages/ruflet/native" <<'PY'
import os, plistlib, re, sys
pkg = sys.argv[1]
manifest = os.path.join(pkg, 'ios/Resources/PrivacyInfo.xcprivacy')
with open(manifest, 'rb') as f:
    info = plistlib.load(f)
ok = True
if info.get('NSPrivacyTracking') is not False or info.get('NSPrivacyTrackingDomains') != []:
    print('::error::PrivacyInfo.xcprivacy must declare no tracking'); ok = False
if info.get('NSPrivacyCollectedDataTypes') != []:
    print('::error::PrivacyInfo.xcprivacy must declare no collected data'); ok = False
declared = {e['NSPrivacyAccessedAPIType']: e.get('NSPrivacyAccessedAPITypeReasons', [])
            for e in info.get('NSPrivacyAccessedAPITypes', [])}
for category, reasons in declared.items():
    if not reasons:
        print(f'::error::{category} has no reason'); ok = False
# Required-reason APIs (Apple's list) as they appear in Dart code: selectors,
# C symbols and keys.
categories = {
    'NSPrivacyAccessedAPICategoryUserDefaults': r'NSUserDefaults|standardUserDefaults',
    'NSPrivacyAccessedAPICategorySystemBootTime': r'systemUptime|mach_absolute_time',
    'NSPrivacyAccessedAPICategoryDiskSpace': r'NSFileSystemFreeSize|NSFileSystemSize|volumeAvailableCapacity|NSURLVolume\w*Capacity|\bstatfs\b|\bstatvfs\b',
    'NSPrivacyAccessedAPICategoryFileTimestamp': r'NSFileCreationDate|NSFileModificationDate|creationDate|contentModificationDate|NSURLContentModificationDateKey|NSURLCreationDateKey|\bfstat\b|\blstat\b|getattrlist',
    'NSPrivacyAccessedAPICategoryActiveKeyboards': r'activeInputModes',
}
used = {}
for base, _, files in os.walk(os.path.join(pkg, 'lib')):
    for name in files:
        if not name.endswith('.dart'): continue
        path = os.path.join(base, name)
        code = '\n'.join(l.split('//')[0] for l in open(path).read().split('\n'))
        for category, pattern in categories.items():
            if re.search(pattern, code):
                used.setdefault(category, []).append(os.path.relpath(path, pkg))
for category, files in sorted(used.items()):
    if category not in declared:
        print(f'::error::{category} is used ({", ".join(files)}) but not declared in PrivacyInfo.xcprivacy')
        ok = False
    else:
        print(f'ok {category}: declared {declared[category]}, used in {", ".join(files)}')
for category in sorted(set(declared) - set(used)):
    print(f'note {category}: declared for a planned feature, not used yet')
sys.exit(0 if ok else 1)
PY
