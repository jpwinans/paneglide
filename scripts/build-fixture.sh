#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bundle="$PWD/.build/WindowFixture.app"
mkdir -p "$bundle/Contents/MacOS"
swiftc -swift-version 6 -module-cache-path .build/ModuleCache Tools/WindowFixture/main.swift -o "$bundle/Contents/MacOS/WindowFixture"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.jpwinans.size-up.fixture</string><key>CFBundleExecutable</key><string>WindowFixture</string><key>CFBundleName</key><string>WindowFixture</string></dict></plist>
PLIST
codesign --force --sign - "$bundle"
printf '%s\n' "$bundle"
