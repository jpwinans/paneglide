# Testing

Run from the repository root using an Xcode toolchain that supports Swift 6:

```sh
bash scripts/test.sh
```

The Swift Testing suite covers layout geometry, display coordinates, window commands
and SnapBack, settings validation and persistence, shortcut registration,
login state, and scripting geometry. It uses
public component interfaces and literal expected results. The suite does not move
real application windows or require Accessibility access.

To select a test, pass Swift's filter option through the script:

```sh
bash scripts/test.sh --filter leftUsesUsableDesktop
```

## Build and packaging checks

```sh
export CODE_SIGN_IDENTITY='your available Apple signing identity'
bash scripts/test-build-replacement.sh
```

The command builds the app, verifies its plist/signature/arm64 architecture,
and checks replacement of the complete output bundle, hardened runtime, and the bundled license. It writes `dist/PaneGlide.app`.
## Native window tests

Follow [Native tests](Native/README.md) to exercise real windows using the disposable
fixture. These tests require an unlocked Mac and Accessibility access for the tested
build. Their generated output belongs in `.build/` or temporary directories.

Run builds and tests sequentially when they share the same `.build` directory.
GitHub Actions is disabled for this repository; checks run locally.
