# Testing

Run from the repository root using Xcode 16 or later with Swift 6 and its Swift
Testing module. Command Line Tools are sufficient to install the app, but may not
include the Testing module required by this suite:

```sh
bash scripts/test.sh
```

The Swift Testing suite covers layout geometry, display coordinates, window commands
and SnapBack, settings validation and persistence, shortcut registration,
login state, per-Mac setup completion, and scripting geometry. It uses
public component interfaces and literal expected results. The suite does not move
real application windows or require Accessibility access.

To select a test, pass Swift's filter option through the script:

```sh
bash scripts/test.sh --filter leftUsesUsableDesktop
```

## Build and packaging checks

```sh
bash scripts/test-build-replacement.sh
```

The command builds the app, verifies its plist/signature/arm64 architecture,
and checks replacement of the complete output bundle, hardened runtime, the bundled
license, and all standard and Retina icon sizes. It writes `dist/PaneGlide.app`.
Local checks use an ad-hoc signature by default. An optional `CODE_SIGN_IDENTITY`
can select an existing local signing identity.

## Installer checks

After building the app, run:

```sh
bash scripts/test-install.sh
```

This exercises `install.sh` against temporary Applications folders. It checks a
fresh installation, complete replacement on update, restoration of the previous
app backup, and preservation of an unrelated app at the destination. The checks do
not launch the app or modify the installed copy. They also exercise default launch
mode with invalid input, to verify validation happens before opening the app.

## Source release checks

```sh
bash scripts/test-package.sh
```

This creates an isolated Git fixture. It verifies a versioned source archive and
checksum without signing credentials, exclusion of build output, and rejection of
uncommitted source without overwriting the previous archive.

## Native window tests

Follow [Native tests](Native/README.md) to exercise real windows using the disposable
fixture. These tests require an unlocked Mac and Accessibility access for the tested
build. Their generated output belongs in `.build/` or temporary directories.

Run builds and tests sequentially when they share the same `.build` directory.
GitHub Actions is disabled for this repository; checks run locally.
