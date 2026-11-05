# Native window tests

These tests control a disposable fixture app containing no user document content.
Run them on an unlocked Mac. Quit other PaneGlide copies and competing window utilities
before testing overlapping shortcuts. Build a signed debug app with Accessibility
access enabled:

```sh
export CODE_SIGN_IDENTITY='your available Apple signing identity'
bash scripts/build-fixture.sh
CONFIGURATION=debug bash scripts/build-app.sh
```

The app's debug test switches are excluded from release builds. See
[Accessibility setup](../../docs/installation.md#enable-accessibility) if the tested
build does not have access. Reopen your usual installed PaneGlide after testing.

## Single-window positioning

```sh
open .build/WindowFixture.app
open -W -n 'dist/PaneGlide.app' --args --integration-test
```

The debug runner targets the fixture by bundle identifier. It exercises layouts,
monitor transfers, alternate widths, and restoration on each connected display,
then exits. It uses temporary in-memory geometry without changing saved preferences.
Inspect `/private/tmp/paneglide-native-test.json`: an ordinary resizable fixture should
report `passed: true`, `restored: true`, and no error.

To test constrained windows, quit the fixture and relaunch it with one of `--fixed`,
`--minimum`, `--aspect`, or `--increments`, then rerun the diagnostic app. For example:

```sh
open .build/WindowFixture.app --args --minimum
open -W -n 'dist/PaneGlide.app' --args --integration-test
```

Constrained requests are expected for these variants. Inspect actual frames and
require restoration; `passed` means every requested frame was attained, so it is
not the success criterion for a deliberately constrained window. The starting fixture
must fit on the test display.

## Multiple-window workflow

```sh
python3 scripts/test-native-workflow.py
```

This runner replaces only its fixture instances, creates four equal-title windows,
and checks five saved configurations: different Center dimensions, independent
percent/point side widths, and Fit beside Center with margins and gaps. It also
checks independent SnapBack, an untouched fourth window, renaming, and close/reopen
identity. Saved app preferences are unchanged.

Expected rectangles are scaled to the primary display’s usable desktop. It needs
at least 1000 × 600 logical points to accommodate the fixture windows. The fixture must remain frontmost during the run. Results are written
to `.build/native-workflow-result.json`; fixture state is recorded independently in
`/private/tmp/paneglide-fixture.json`.

## Public scripting

Launch exactly one replacement build before this check:

```sh
open 'dist/PaneGlide.app'
python3 scripts/test-native-scripting.py
```

The runner launches and focuses a fresh fixture, exercises the public scripting
commands, checks point/rectangle arguments and batch results, and verifies restoration
using the fixture's own frame record. It refuses to send commands if the lock screen
is active or the fixture did not become frontmost. Avoid changing focus during the
short run. The output is `.build/native-scripting-result.json`.

These tests supplement interactive checks of physical shortcuts, menu targeting,
preference controls, and the applications you use. A blocked or constrained test
needs inspection rather than being treated as a successful layout.

## Setup and help

On a fresh user account, start the installed app and check that Quick Start appears
without opening System Settings until requested. Accessibility status must reflect
the actual grant when returning from System Settings; Start Using PaneGlide is
available only after access is granted and enabled shortcuts have registered.
A conflicting shortcut should be explained inside Quick Start, with Retry Shortcuts
available after resolving the conflict. Disabled or unassigned shortcuts should
allow completion for menu-only use. Closing setup without completing it should
leave it available on the next launch. Existing configured installations with
Accessibility access should start quietly.

Open Quick Start from Preferences → General and from the menu. Open Help from the menu. Check both tabs and scroll the guide.
Choose Edit Shortcuts and confirm Preferences opens directly to its shortcut editor.
Choose Configure Center & Side Panes and confirm the editable Window Sizes tab
opens, with display selection and configurable Center/alternate sizes.
Record a temporary shortcut, cancel or revert it, and check that saved bindings
remain intact. Check that opening Preferences from Help works and that Help remains usable offline. Login changes
should reflect the macOS registration result. Do not revoke an everyday
installation's permission just to exercise a fresh-user case.

For the optional practice check, choose Try Left → SnapBack, then focus a normal
fixture window and use Left. Return to Help to confirm “The window moved.” SnapBack
on the same window must produce “Move and restore confirmed.” An unchanged window,
a restore on another window, or a constrained/failed restore must not complete the
check. Canceling it must leave normal SnapBack restoration available. Test with
physical shortcuts and with menu actions; no synthetic key injection is required.

### Fresh-account acceptance

Use a separate macOS account or another Mac without PaneGlide settings or an
Accessibility grant. Build from the published source ZIP with `bash install.sh`.
Before granting access, Quick Start must show access is needed and prevent setup
completion. Grant access and return to verify the live status. If an existing
window utility conflicts, resolve the conflict and use Retry Shortcuts. Complete
the optional practice check with a physical keyboard, then configure and try the
alternate side widths. Finish setup, quit, and reopen: the tour should stay closed.
Enable startup only if desired and check it after the next login.

A fresh build directory or isolated preferences test does not establish this OS
permission experience. Record which of these checks were actually performed in the
release pull request, and keep outstanding interactive checks explicit.
