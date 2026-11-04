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
must fit on the test display. The optional legacy drawer runner is
`scripts/test-native-drawer.py` and uses its own disposable fixture.

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
