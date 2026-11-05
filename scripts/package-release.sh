#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit all source changes before packaging a release.' >&2; exit 1; }
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'The app version must be major.minor.patch.' >&2; exit 1; }
mkdir -p dist
release_directory="$(mktemp -d "$PWD/dist/.paneglide-release.XXXXXX")"
trap 'rm -rf "$release_directory"' EXIT
git archive --format=zip --prefix="PaneGlide-$version/" --output="$release_directory/PaneGlide-source.zip" HEAD
(cd "$release_directory" && shasum -a 256 PaneGlide-source.zip > SHA256SUMS.txt)
mv "$release_directory/PaneGlide-source.zip" dist/PaneGlide-source.zip
mv "$release_directory/SHA256SUMS.txt" dist/SHA256SUMS.txt
printf 'Source release %s: dist/PaneGlide-source.zip and dist/SHA256SUMS.txt\n' "$version"
