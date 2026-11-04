#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CODE_SIGN_IDENTITY:?Set the identity used to sign dist/PaneGlide.app}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
fixture_root="$(mktemp -d "${TMPDIR:-/private/tmp}/paneglide-signed-update.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT
/usr/bin/ditto "dist/PaneGlide.app" "$fixture_root/Installed.app"
/usr/bin/ditto "dist/PaneGlide.app" "$fixture_root/Candidate.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 99.0.1' "$fixture_root/Candidate.app/Contents/Info.plist"
/usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" "$fixture_root/Candidate.app"
swift run --disable-sandbox UpdateAcceptance "$fixture_root/Installed.app" "$fixture_root/Candidate.app" --install
# Alter a sealed resource after signing; the installed build must remain usable.
printf 'tampered fixture\n' >> "$fixture_root/Candidate.app/Contents/Resources/PaneGlide.sdef"
if swift run --disable-sandbox UpdateAcceptance "$fixture_root/Installed.app" "$fixture_root/Candidate.app"; then
    echo 'FAIL: tampered app was accepted' >&2
    exit 1
fi
/usr/bin/codesign --verify --strict "$fixture_root/Installed.app"
echo 'PASS: signed update, retained previous build, tampered update rejection'
