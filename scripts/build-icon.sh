#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
destination="${1:-$project_root/dist/AppIcon.icns}"
mkdir -p "$(dirname "$destination")"
icon_root="$(mktemp -d "${TMPDIR:-/tmp}/paneglide-icon.XXXXXX")"
trap 'rm -rf "$icon_root"' EXIT
iconset="$icon_root/AppIcon.iconset"
mkdir -p "$iconset"

for size in 16 32 128 256 512; do
    for scale in 1 2; do
        suffix=''
        if [[ "$scale" == 2 ]]; then suffix='@2x'; fi
        pixels=$((size * scale))
        sips --resampleHeightWidth "$pixels" "$pixels" Resources/AppIcon.png \
            --out "$iconset/icon_${size}x${size}${suffix}.png" >/dev/null
    done
done
iconutil --convert icns --output "$destination" "$iconset"
