# Release packaging

This guide is for maintainers creating downloadable releases. PaneGlide does not
check for or install updates. Users can open **View on GitHub…** from the menu to
find the source and [release downloads](https://github.com/jpwinans/paneglide/releases).

## Build a release package

Public packages require a **Developer ID Application** certificate and a configured
`notarytool` Keychain profile. See Apple's [notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
for setting up that profile. Never add signing keys or notarization credentials to
the repository.

From the repository root:

```sh
export CODE_SIGN_IDENTITY='Developer ID Application: your signing identity'
export NOTARYTOOL_PROFILE='your configured notarytool profile'
export PANEGLIDE_VERSION=0.2.0
bash scripts/package-release.sh
```

The script builds optimized arm64 code with hardened runtime and a secure signing
timestamp, verifies the Developer ID signature, submits for notarization, staples
and validates the ticket, checks Gatekeeper, and creates `dist/PaneGlide.zip`.
It also creates `dist/PaneGlide-source.zip` from the exact, clean source commit.
Failures stop packaging; an unnotarized build is not a public release.

Publish both archives on a GitHub release with the matching version tag. Keep the
corresponding source available alongside the binary under GPL v3. Source-only
releases include only the corresponding source archive.

Keep using the installation's signing identity for updates. A signing-identity
change requires a separate installation and permission setup. Use
`scripts/build-app.sh` for local development builds; the public packaging script
requires distribution credentials. See the [testing guide](../Tests/README.md)
for local build checks.
