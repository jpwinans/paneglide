#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Type-check the production app without SDK macro plugin discovery. Full Xcode's
# Swift driver supplies plugins that standalone Command Line Tools can lack.
# Calling the frontend directly keeps that difference visible in this check.
check_directory="$(mktemp -d "${TMPDIR:-/tmp}/paneglide-compiler-test.XXXXXX")"
trap 'rm -rf "$check_directory"' EXIT
sdk_path="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
compiler_options=(-swift-version 6 -target arm64-apple-macos14.0 -sdk "$sdk_path")
/usr/bin/xcrun swift-frontend -frontend -emit-module -parse-as-library \
    "${compiler_options[@]}" -module-name PaneGlideCore \
    Sources/PaneGlideCore/*.swift -o "$check_directory/PaneGlideCore.swiftmodule"
/usr/bin/xcrun swift-frontend -frontend -typecheck \
    "${compiler_options[@]}" -module-name PaneGlideApp -I "$check_directory" \
    Sources/PaneGlideApp/*.swift
printf 'PASS: the production app type-checks without SDK macro plugins.\n'
