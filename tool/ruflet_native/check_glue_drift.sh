#!/usr/bin/env bash
# Every service glue file in ruflet_native is today's service file copied
# verbatim with recorded substitutions, and so is any other file ported from
# an engine package (flashlight's backend, from ruflet_flashlight). This
# re-applies the substitutions to the current source and fails on any
# difference, so a later fix to a core or extension service cannot silently
# diverge from the copy (SPEC §3.3).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
exec dart run tool/ruflet_native/check_glue_drift.dart "$@"
