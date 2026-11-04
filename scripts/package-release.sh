#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CODE_SIGN_IDENTITY:?Set a Developer ID Application signing identity}"
: "${NOTARYTOOL_PROFILE:?Set an existing notarytool Keychain profile}"
: "${PANEGLIDE_VERSION:?Set the release version as major.minor.patch}"
[[ "$CODE_SIGN_IDENTITY" != - ]] || { echo 'Public packages require Developer ID signing.' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit all source changes before packaging a release.' >&2; exit 1; }
CONFIGURATION=release bash scripts/build-app.sh
bundle="$PWD/dist/PaneGlide.app"
signature_details="$(codesign --display --verbose=4 "$bundle" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<< "$signature_details" || { echo 'Public packages require a Developer ID Application certificate.' >&2; exit 1; }
release_directory="$(mktemp -d "$PWD/dist/.paneglide-release.XXXXXX")"
trap 'rm -rf "$release_directory"' EXIT
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$bundle" "$release_directory/PaneGlide.zip"
xcrun notarytool submit "$release_directory/PaneGlide.zip" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$bundle"
xcrun stapler validate "$bundle"
spctl --assess --type execute --verbose=2 "$bundle"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$bundle" "$release_directory/PaneGlide.zip"
git archive --format=zip --prefix="PaneGlide-$PANEGLIDE_VERSION/" --output="$release_directory/PaneGlide-source.zip" HEAD
mv "$release_directory/PaneGlide.zip" dist/PaneGlide.zip
mv "$release_directory/PaneGlide-source.zip" dist/PaneGlide-source.zip
printf 'Packages: %s/dist/PaneGlide.zip and PaneGlide-source.zip\n' "$PWD"
