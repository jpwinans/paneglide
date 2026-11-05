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
icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' 'dist/PaneGlide.app/Contents/Info.plist')"
icon_check_directory="$(mktemp -d "$PWD/.build/icon-check.XXXXXX")"
trap 'rm -rf "$icon_check_directory"' EXIT
iconutil --convert iconset --output "$icon_check_directory/AppIcon.iconset" "dist/PaneGlide.app/Contents/Resources/$icon_name"
for representation in 'icon_16x16.png' 'icon_16x16@2x.png' 'icon_32x32.png' 'icon_32x32@2x.png' 'icon_128x128.png' 'icon_128x128@2x.png' 'icon_256x256.png' 'icon_256x256@2x.png' 'icon_512x512.png' 'icon_512x512@2x.png'; do
    [[ -s "$icon_check_directory/AppIcon.iconset/$representation" ]] || { echo "FAIL: missing icon representation $representation" >&2; exit 1; }
done
echo 'PASS: complete native app bundle replaced, signature verified, and all icon sizes decoded'
