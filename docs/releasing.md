# Release packaging

PaneGlide releases contain source code for users to build locally with `install.sh`.
They do not require a signing certificate, notarization credentials, or an Apple
developer account. No prebuilt app is published. GitHub Actions stays disabled;
release checks run locally. Use Xcode 16 or later for the Swift test suite; its
Swift Testing module is not included in every Command Line Tools package.

## Prepare a release

1. Update both version fields in `Resources/Info.plist` to the same
   `major.minor.patch` value. Update the user guides for changed behavior.
2. Run the checks from the repository root:

   ```sh
   bash scripts/test.sh
   CONFIGURATION=release bash scripts/build-app.sh
   bash scripts/test-install.sh
   bash scripts/test-package.sh
   ```

3. Complete the relevant [native checks](../Tests/Native/README.md). Include setup
   and shortcut editing when those screens change. Record actual validation in the
   pull request; do not claim checks that could not be run.
4. Merge the release changes. From the clean merged commit, run:

   ```sh
   bash scripts/package-release.sh
   ```

The packager takes the version from `Resources/Info.plist` and archives the exact
committed source. It rejects uncommitted changes and creates:

- `dist/PaneGlide-source.zip`, with a `PaneGlide-<version>/` top-level folder.
- `dist/SHA256SUMS.txt`, containing the archive's SHA-256 checksum.

Only tracked files are packaged; build outputs and local settings are excluded.
Inspect the archive for the installer, source, artwork, documentation, and license.
Extract it into a temporary folder, open Terminal in that extracted folder, and run:

```sh
bash install.sh --applications-dir "$PWD/Temporary Applications" --no-launch
```

Leave `CODE_SIGN_IDENTITY` unset. This checks the same path a new user will take. Use the selected Command Line
Tools and a clean build directory when validating that toolchain.

## Publish

Tag the tested commit as `v<version>`. Create a GitHub release for that tag and attach
**only** `PaneGlide-source.zip` and `SHA256SUMS.txt`. Retain the archive name so the
README's latest-download link remains valid. State the macOS, architecture, and
Swift requirements; link the installation guide. Users should be able to install
by extracting the archive and running `bash install.sh`.

Publish a new version for subsequent changes instead of replacing an existing tag.
Never add signing keys, private settings, or credentials to a source archive.

## Verify a downloaded archive

Download both files into the same folder, then run there:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

The result should be `PaneGlide-source.zip: OK`. The checksum detects a damaged or
changed download; it is not a substitute for obtaining both files from the official
[PaneGlide release](https://github.com/jpwinans/paneglide/releases).
