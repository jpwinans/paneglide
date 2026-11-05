# Installation

## Requirements

- An Apple silicon Mac running macOS 14 or later. PaneGlide runs natively as arm64.
- Accessibility access to move and resize other applications' windows.
- To build from source: Xcode 16 or later (Swift 6), available from Apple.

## Install the app

There is no notarized download yet. Start with [Build from source](#build-from-source).

When a `PaneGlide.zip` package is available on [Releases](https://github.com/jpwinans/paneglide/releases), unzip it in Finder. Move **PaneGlide.app** to
`~/Applications` (the Applications folder inside your home folder), then open it.
Keep the app in that location so startup registration and future updates use the
same installation. The app appears in the menu bar rather than keeping a Dock icon.

For an existing installation, quit PaneGlide and replace the complete app in the
same location using Finder. Keep a copy of the previous app until the new version
works. Saved settings are stored separately and survive app replacement.

Disable matching shortcuts in other window utilities before enabling PaneGlide's
shortcuts, so only one app responds to each key combination.

## Enable Accessibility

1. Open System Settings → Privacy & Security → Accessibility.
2. Add your installed **PaneGlide.app** if it is not listed, then enable it.
3. Return to PaneGlide → Preferences → General. The status refreshes automatically
   and should read **Accessibility access is enabled**.
4. Focus an ordinary application window and try a positioning shortcut.

If access appears enabled but actions fail after replacing a development build,
quit PaneGlide and reopen the installed copy. If General still reports no access,
remove only the new **PaneGlide** entry from Accessibility, add the installed app
again, and enable it. A consistent signing identity reduces the need to refresh
this grant between builds.

## Start at login

In Preferences → General, enable **Start PaneGlide automatically at login**. This
switch takes effect immediately, without Apply. Its status reports the macOS
registration result. If approval is required, use **Open Login Items Settings…**
and approve PaneGlide there.

Leave **Show preferences on launch** off to start quietly in the menu bar. Changes
to that option require **Apply**. Reopen the app from Finder whenever you want its
preferences, including when the menu icon is hidden.

## Build from source

1. Install Xcode 16 or later from the Mac App Store. Open it once to finish its
   setup. If `swift --version` reports a version below 6, select your Xcode toolchain
   in Xcode → Settings → Locations → Command Line Tools.
2. Open Terminal and run:

```sh
git clone https://github.com/jpwinans/paneglide.git
cd paneglide
swift --version
bash scripts/test.sh
CONFIGURATION=release bash scripts/build-app.sh
mkdir -p "$HOME/Applications"
ditto dist/PaneGlide.app "$HOME/Applications/PaneGlide.app"
open "$HOME/Applications/PaneGlide.app"
```

These installation commands assume PaneGlide is not already installed. Quit an
existing copy before replacing it. The app opens in the menu bar; finish the
[Accessibility setup](#enable-accessibility) before trying shortcuts.

The default local build is ad-hoc signed and needs no developer account. macOS may
require you to remove and re-add its Accessibility entry after rebuilding. You can update local builds with the same build and installation steps after
fetching the new source. Quit PaneGlide and replace the complete installed bundle
in Finder to avoid retaining files from the previous build.

For a stable development signature, list your available identities and select
one in your shell before building:

```sh
security find-identity -v -p codesigning
export CODE_SIGN_IDENTITY='your signing identity from the list'
CONFIGURATION=release bash scripts/build-app.sh
```

The build produces `dist/PaneGlide.app`, includes the GPL license, enables hardened
runtime, and verifies the plist, arm64 architecture, and signature. An Apple
Development signature is suitable for your local installation; a public download
requires Developer ID signing and notarization. See [release packaging](releasing.md#build-a-release-package).

Omit `CONFIGURATION=release` for a debug build with native fixture test controls.
Set `PANEGLIDE_VERSION=major.minor.patch` to override the version in `Resources/Info.plist`.

## Remove the app

Turn off **Start PaneGlide automatically at login**, then choose **Quit PaneGlide**
from the menu. Move the app to Trash. Saved preferences remain in
`~/Library/Application Support/PaneGlide/` so reinstalling can reuse them.

Settings exports do not include the macOS login registration or Accessibility grant.
