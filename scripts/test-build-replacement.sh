#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
previous_bundle_inode=''
if [[ -d 'dist/PaneGlide.app' ]]; then previous_bundle_inode="$(stat -f '%i' 'dist/PaneGlide.app')"; fi
bash scripts/build-app.sh
new_bundle_inode="$(stat -f '%i' 'dist/PaneGlide.app')"
[[ "$previous_bundle_inode" != "$new_bundle_inode" ]] || { echo 'FAIL: rebuild reused the existing bundle directory' >&2; exit 1; }
codesign --verify --strict 'dist/PaneGlide.app'
signature_details="$(codesign --display --verbose=4 'dist/PaneGlide.app' 2>&1)"
grep -q 'flags=.*runtime' <<< "$signature_details" || { echo 'FAIL: app does not enable hardened runtime' >&2; exit 1; }
lipo -verify_arch arm64 'dist/PaneGlide.app/Contents/MacOS/PaneGlide'
cmp LICENSE 'dist/PaneGlide.app/Contents/Resources/LICENSE'
echo 'PASS: complete native app bundle replaced and signature verified'
