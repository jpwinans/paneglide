#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")" && pwd)"
applications_directory="$HOME/Applications"
built_app=''
launch_option=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --applications-dir|--app)
            [[ $# -ge 2 && -n "$2" ]] || { echo "$1 requires a path." >&2; exit 2; }
            if [[ "$1" == --applications-dir ]]; then applications_directory="$2"; else built_app="$2"; fi
            shift 2 ;;
        --no-launch) launch_option=--no-launch; shift ;;
        --help|-h)
            cat <<'HELP'
Usage: bash install.sh [options]

Build PaneGlide locally, install it in ~/Applications, and open it.
No developer account or distribution certificate is needed.

Options:
  --applications-dir PATH  Choose another Applications folder.
  --no-launch              Install without opening the app.
  --app PATH               Install an already-built PaneGlide.app.
  --help                   Show this help.
HELP
            exit 0 ;;
        *) echo "Unknown option: $1. Run bash install.sh --help." >&2; exit 2 ;;
    esac
done

[[ "$(uname -s)" == Darwin ]] || { echo 'PaneGlide requires macOS.' >&2; exit 1; }
[[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]] || { echo 'PaneGlide requires an Apple silicon Mac.' >&2; exit 1; }
macos_version="$(/usr/bin/sw_vers -productVersion)"
[[ "${macos_version%%.*}" -ge 14 ]] || { echo 'PaneGlide requires macOS 14 or later.' >&2; exit 1; }

if [[ -z "$built_app" ]]; then
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
        echo "Install Apple's free developer tools first: xcode-select --install" >&2
        echo 'When installation finishes, run bash install.sh again.' >&2
        exit 1
    fi
    if ! swift_version="$(/usr/bin/xcrun swift --version 2>&1)"; then
        echo 'The Swift compiler could not start. Finish developer-tool setup, then try again.' >&2
        echo "$swift_version" >&2
        exit 1
    fi
    swift_major="$(sed -nE 's/.*Swift version ([0-9]+).*/\1/p' <<< "$swift_version" | head -1)"
    if [[ -z "$swift_major" || "$swift_major" -lt 6 ]]; then
        echo 'PaneGlide needs Swift 6 or later. Update the Command Line Tools or install Xcode 16 or later, then try again.' >&2
        exit 1
    fi
    if ! /usr/bin/xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
        echo 'The macOS developer tools are incomplete. Finish installing the Command Line Tools or Xcode, then try again.' >&2
        exit 1
    fi
    echo 'Building PaneGlide on your Mac…'
    CONFIGURATION=release bash "$project_root/scripts/build-app.sh"
    built_app="$project_root/dist/PaneGlide.app"
fi
/usr/bin/python3 "$project_root/scripts/install-app.py" --app "$built_app" --applications-dir "$applications_directory" ${launch_option:+"$launch_option"}
