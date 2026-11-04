# PaneGlide

PaneGlide is a native Apple silicon macOS menu bar app for moving and resizing windows
with keyboard shortcuts. It supports halves, quarters, Center, Full Screen, monitor
transfers, SnapBack, and configurable alternate Left and Right widths for ultrawide
layouts.

## Get started

The current release is source-only. Follow [Build from source](docs/installation.md#build-from-source)
to create the app; no paid developer account is required for a local build. A
notarized download is not available yet.


1. Install **PaneGlide.app** in `~/Applications` and open it. Requires an Apple silicon
   Mac running macOS 14 or later.
2. Enable **PaneGlide** in System Settings → Privacy & Security → Accessibility.
3. Open Preferences from its menu bar icon. Enable **Start PaneGlide automatically at
   login** if desired; macOS reports the registration state beneath the switch.
4. Focus a window and press **Control–Option–Command–Left** or
   **Control–Option–Command–Right**. Use **Control–Option–Command–/** for SnapBack.

Use Preferences → Window Sizes to enable alternate side widths. A repeated Left or
Right action toggles between the normal split and the configured alternate width.
Center dimensions, side widths, margins, and partitions can differ by display.
Choose **Apply** to save preference edits.

## Documentation

- [Installation](docs/installation.md): install, build from source, Accessibility, and startup.
- [Configuration](docs/configuration.md): every preference, display profiles, and settings backup.
- [Usage](docs/usage.md): default shortcuts, ultrawide layouts, monitor moves, and troubleshooting.
- [AppleScript](docs/scripting.md): commands, custom layouts, and batch arrangements.
- [Updates](docs/updates.md): optional public release checks, installation, and packaging.
- [Tests](Tests/README.md): local checks and native window tests.

## License

Copyright (c) 2026 jpwinans. PaneGlide is licensed under the
[GNU General Public License, version 3 only](LICENSE) (`GPL-3.0-only`).

## Source layout

| Directory | Contents |
| --- | --- |
| `Sources/PaneGlideCore/` | Geometry, window commands, settings, shortcuts, and update logic |
| `Sources/PaneGlidePlatform/` | Native app signature verification |
| `Sources/PaneGlideApp/` | Menu bar app, preferences, Accessibility, and macOS services |
| `Tools/` | Disposable window fixture and update test helper |
| `Tests/` | Automated tests and native test instructions |
| `docs/` | Installation, configuration, usage, and scripting guides |

The app uses Swift, AppKit, and SwiftUI with no third-party package dependencies.
