# Updates and release packages

PaneGlide checks public [GitHub releases](https://github.com/jpwinans/paneglide/releases).
No GitHub account or token is needed. Update checking is optional and starts disabled.
Window positioning and configuration work offline.

## Configure release checks

Choose **Check for Updates Now** in Preferences → General for a manual check. To
check at startup and every 24 hours while running, enable **Check for updates
automatically (daily)** and choose Apply. Checks notify you of available packages;
they do not download or install updates automatically.

Only published releases with a numeric `major.minor.patch` tag (optionally prefixed
with `v`) and a `PaneGlide.zip` asset are offered. Drafts, prereleases, and source-only
releases are ignored. Network failures and GitHub request limits show an error;
retry later instead of treating the failure as an up-to-date result.

Checks contact GitHub's public API. They do not send window titles, layouts, saved
preferences, or application usage. Download links open in your browser.

## Install an update

1. Choose **Open Releases…**, download `PaneGlide.zip`, and unzip it in Finder.
2. Choose **Install Downloaded App…** and select the extracted **PaneGlide.app**.
3. Wait for the status to confirm installation. It also reports where the previous
   app was retained.
4. Quit PaneGlide and reopen the installed copy from Finder.

The installer checks the app's signature against the installed app's signing
requirement, its bundle identifier, native arm64 executable, newer version, and
minimum macOS version. Ad-hoc, modified, wrong-signer, Intel-only, or non-newer
candidates are rejected. The containing installation directory must be writable
by your account; `~/Applications` is suitable.

The verified candidate replaces the complete bundle atomically. The old bundle is
retained in a hidden backup beside the installation. Installation errors leave the
existing app intact. Saved preferences stay in Application Support. After reopening,
check the Accessibility and login status in General. SnapBack history resets when
the app quits.

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
releases may omit `PaneGlide.zip`; update checking will ignore them.

Keep using the installation's signing identity for updates. A signing-identity
change requires a separate installation and permission setup. Use
`scripts/build-app.sh` for local development builds; the public packaging script
requires distribution credentials. See the [testing guide](../Tests/README.md)
for disposable signed-update checks.
