#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
/usr/bin/xcrun swiftc -swift-version 6 -module-cache-path .build/ModuleCache Sources/PaneGlideCore/Layout.swift Tools/RenderLayoutDemo/main.swift -o .build/render-layout-demo
.build/render-layout-demo
