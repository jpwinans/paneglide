# Configuration

Open **Preferences…** from the PaneGlide menu bar icon, or reopen the app from Finder.
Most edits are a draft: choose **Apply** (Command–Return) to save them, or
**Revert Unsaved Changes** to return to saved values. Closing Preferences discards
unsaved edits. Invalid values produce an explanation and leave saved settings intact.

The login switch takes effect immediately. It is not
part of the preference draft.

## General

| Setting | Behavior |
| --- | --- |
| Start PaneGlide automatically at login | Registers or unregisters the installed app with macOS immediately; the status below shows the result |
| Show preferences on launch | Opens Preferences when the app starts |
| Accessibility Access… / Refresh Access Status | Opens access guidance or checks the current grant |
| Show PaneGlide in menu bar | Shows or hides the status icon; reopen the app from Finder to recover Preferences when hidden |
| Show tooltips | Enables explanatory help on supported controls |
| Show visual action overlay | Briefly shows action feedback; errors still display useful messages |

## Shortcuts

Click an action's shortcut button, then press a key combination containing Command,
Option, or Control. Escape cancels recording; Delete with no modifiers clears the
binding. Choose **Apply** to activate the changes.

Duplicate combinations are rejected. If another app owns a shortcut, registration
fails with an explanation and the previous bindings are retained. Quit or disable
the conflicting utility, then retry. **Restore Default Shortcuts** restores all
bindings in the draft without changing geometry settings.

**Enable shortcuts** controls all global bindings. Menu and scripting commands
remain available when shortcuts are disabled. Each **Show in menu** toggle controls
only whether that action appears in the menu; hiding an action leaves its shortcut
available. The [usage guide](usage.md#default-shortcuts) lists the default bindings.

## Global defaults and display profiles

Margins, Partitions, and Window Sizes share a **Display settings** picker:

1. Select **Global defaults** to edit the geometry used by displays without overrides.
2. Select a connected display and enable **Use separate settings for this display**
   to create an independent profile, initially copied from the global defaults.
3. Edit its geometry and choose **Apply**.

Turning separate settings off removes that display's override when applied, so it
inherits global defaults again. Editing global defaults does not change existing
overrides. Disconnected profiles are retained and remain selectable. If macOS cannot
uniquely identify a display, it uses global defaults and retains saved profiles.

Shortcuts, appearance, and Advanced options apply across displays.

## Dimensions and usable space

Layouts use the desktop area available around the menu bar and Dock, reduced by any
enabled edge margins. Percentages refer to this remaining area. Fixed dimensions
are **logical macOS points**, not physical pixels; on a 2× Retina display, one point
spans two physical pixels.

Center width and height can each use percent or points. Alternate side widths can
also use either unit. Valid sizes are positive; percentages cannot exceed 100.
An otherwise valid fixed size that exceeds the available space is capped when the
layout is applied. Applications may impose their own minimum sizes.

## Margins

**Screen edge margins** sets independent Top, Left, Bottom, and Right distances in
points. **Space between windows** sets Horizontal and Vertical partition gaps.
The two enable switches are independent and preserve the entered values when off.

For split and quarter layouts, a gap is shared across the adjoining partition edge.
It is not added to the outer screen edges. Center uses the area inside edge margins;
Fit beside Center uses the horizontal gap to separate side windows from Center.

## Partitions

**Split screen partitions** controls the left width and upper height used by Left,
Right, Up, and Down. **Quarter screen partitions** controls those dividers
independently for the four corner actions. Values must be greater than 0% and less
than 100%.

**Reset Split** restores only the split pair to 50%/50%. **Reset Quarters** restores
only the quarter pair. Choose Apply to save either reset.

## Window Sizes: Center

Enable **Resize when centering** to set Center's width and height. Turn it off to
center the current window without changing its size. Width and height are independent
of the normal split and alternate side widths.

For a new configuration, Center resizes to 50% width and 100% height. These are editable
defaults, not a required three-column layout.

## Window Sizes: repeated Left and Right

Enable **Alternate Left**, **Alternate Right**, or both. Each action uses its normal
split unless the window already matches that normal region; repeating it then applies
the alternate width. A further press returns to the normal split. Left stays anchored
to the left edge, Right to the right edge, and both use the full available height.
The decision uses current window geometry rather than a double-press timer.

- Enter an independent percentage or point width for each side.
- Enable **Use the left alternate width for both sides** to share the left side's
  width and Fit beside Center choice. Each side's enable switch remains independent.
- Enable **Fit beside Center** to derive the available side width from the configured
  Center width and horizontal gap. Center resizing must be enabled, with enough space
  left for the side windows.

Fit beside Center does not inspect or reposition another window. Apply Center to
your main window separately. The preview shows the configured Center and side regions.
Alternate widths start disabled in a new configuration.

## Advanced

| Setting | Behavior |
| --- | --- |
| Resize windows proportionally when changing monitors | Scales window size to the destination's usable area; when off, retains size where it fits |
| Center windows that do not resize fully | Centers an app's constrained window within the requested region |
| Try to keep windows in bounds | Keeps windows within the available display bounds where possible |

These are best-effort options. An app can refuse resizing or impose minimum sizes,
fixed proportions, or resize increments. PaneGlide uses the actual result and reports
when the app limits the requested layout.

## Save, export, and import

Saved preferences live at `~/Library/Application Support/PaneGlide/settings.json`.
Use the preference controls rather than editing this file while the app is running.

**Export Saved Settings…** exports the saved configuration, including display
profiles. Unsaved draft changes are not included. **Import…** loads a settings file
into the draft; review it and choose Apply to save it. Invalid imports do not replace
the current configuration. Profiles for disconnected displays are retained.

Exports do not include macOS login registration, Accessibility
grants, or SnapBack history. If a settings document cannot be loaded, the app preserves
it as a `settings-recovery-<identifier>.json` file in the same folder, uses defaults,
and reports the backup location.
