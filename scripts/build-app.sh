#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
configuration="${CONFIGURATION:-debug}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$project_root/.build/ModuleCache}"

build_options=(--disable-sandbox --configuration "$configuration" --arch arm64)
/usr/bin/xcrun swift build "${build_options[@]}" --product PaneGlide
binary_directory="$(/usr/bin/xcrun swift build "${build_options[@]}" --show-bin-path)"
mkdir -p "$project_root/dist"
staging_root="$(mktemp -d "$project_root/dist/.paneglide-build.XXXXXX")"
trap 'rm -rf "$staging_root"' EXIT
bundle="$staging_root/PaneGlide.app"
destination="$project_root/dist/PaneGlide.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_directory/PaneGlide" "$bundle/Contents/MacOS/PaneGlide"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/PaneGlide.sdef "$bundle/Contents/Resources/PaneGlide.sdef"
bash scripts/build-icon.sh "$bundle/Contents/Resources/AppIcon.icns"
cp LICENSE "$bundle/Contents/Resources/LICENSE"
if [[ -n "${PANEGLIDE_VERSION:-}" ]]; then
    [[ "$PANEGLIDE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "PANEGLIDE_VERSION must be major.minor.patch" >&2; exit 1; }
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PANEGLIDE_VERSION" "$bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $PANEGLIDE_VERSION" "$bundle/Contents/Info.plist"
fi
plutil -lint "$bundle/Contents/Info.plist"
signing_options=(--force --options runtime --sign "${CODE_SIGN_IDENTITY:--}")
if [[ "${CODE_SIGN_IDENTITY:--}" != - ]]; then signing_options+=(--timestamp); fi
codesign "${signing_options[@]}" "$bundle"
codesign --verify --strict "$bundle"
/usr/bin/lipo "$bundle/Contents/MacOS/PaneGlide" -verify_arch arm64
# Replace the complete bundle only after validation, preserving the last valid
# build on failure and avoiding reuse of a development bundle's directory identity.
/usr/bin/python3 - "$bundle" "$destination" <<'PY'
import ctypes
import os
import sys

source, destination = map(os.fsencode, sys.argv[1:])
if os.path.exists(destination):
    library = ctypes.CDLL(None, use_errno=True)
    swap = library.renamex_np
    swap.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    swap.restype = ctypes.c_int
    if swap(source, destination, 2) != 0:  # Darwin RENAME_SWAP
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))
else:
    os.rename(source, destination)
PY
printf 'Built %s\n' "$destination"
