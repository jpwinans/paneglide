# Contributing to PaneGlide

Bug reports, documentation improvements, and focused pull requests are welcome.
Follow the [Code of Conduct](CODE_OF_CONDUCT.md). For a larger feature, open a
[feature request](https://github.com/jpwinans/paneglide/issues/new/choose) first so
its behavior and scope can be discussed.

## Report a problem

Search existing issues before opening a new one. Include the PaneGlide and macOS
versions, the affected application, steps to reproduce, and expected versus actual
behavior. For layout problems, include your display arrangement, scaling, relevant
margins, and whether a display has its own profile. Use a small reproducible example;
crop private information from screenshots.

Report security vulnerabilities through [Security](SECURITY.md), not a public issue.

## Set up a local checkout

Use an Apple silicon Mac with macOS 14 or later and Xcode 16 or later with Swift 6
for development and the automated Swift tests. Installing the app only needs the
Command Line Tools; the test suite also needs the Swift Testing module included
with Xcode.
Fork the repository, clone your fork, and create a branch from `main`. There are no
third-party package dependencies.

```sh
bash scripts/test.sh
bash scripts/test-command-line-build.sh
CONFIGURATION=release bash scripts/build-app.sh
```

The app is built at `dist/PaneGlide.app`. Follow the
[installation guide](docs/installation.md) to install a development copy and grant
Accessibility access. A local ad-hoc build needs no developer account. If you use
a signing identity, configure it locally with `CODE_SIGN_IDENTITY`; keep signing
keys and credentials out of the repository. For example:

```sh
CODE_SIGN_IDENTITY='your local signing identity' bash install.sh
```

Using the same local signing identity can preserve Accessibility authorization
between builds. It is optional and is not used to distribute public binaries.
Without it, use the default local ad-hoc signature and refresh the Accessibility
entry if macOS requests it. `bash install.sh --app "$PWD/dist/PaneGlide.app"`
installs an already-built bundle. Omit `CONFIGURATION=release` from the build script
for a debug build with fixture-test controls. `PANEGLIDE_VERSION=major.minor.patch`
can override the local app version; release archives always use the committed plist.

## Make a focused change

- Keep geometry and behavior in `PaneGlideCore` and macOS integration in `PaneGlideApp`.
- Favor the simplest solution that handles the required behavior. Match nearby code.
- For behavior changes, start with a failing test at the relevant public interface,
  implement the change, then refactor while the tests remain green.
- Use native window tests when the change depends on Accessibility or scripting.
  These tests operate on a disposable fixture; they require an unlocked Mac.
- For artwork or documentation, use relevant build, visual, and link checks instead
  of adding tests that only repeat the implementation.
- Update user documentation when a command, preference, or installation step changes.

See [Testing](Tests/README.md) for commands and native acceptance setup. Run builds
and tests sequentially when they share `.build`. GitHub Actions is disabled; checks
run locally, and pull requests should state what was actually verified.

## Open a pull request

Target `main`. Explain the user-visible change and list validation commands and
results. Include a screenshot for visual changes, using a clean fixture without
private content. Mention checks you could not run. Keep unrelated formatting and
refactoring out of the change.

The source is licensed under [GPL-3.0-only](LICENSE); contributions use the same
license. Do not include code or assets you do not have permission to contribute.
