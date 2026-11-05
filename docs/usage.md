# Using PaneGlide

Focus the window you want to arrange, then use a shortcut or choose an action from
the PaneGlide menu bar icon. Actions target that window. They do not automatically
rearrange your other windows.

## Default shortcuts

Control = ⌃, Option = ⌥, Command = ⌘, Shift = ⇧. These are the initial bindings;
Preferences → Shortcuts lets you change or clear any of them.

| Action | Shortcut |
| --- | --- |
| Left | ⌃⌥⌘← |
| Right | ⌃⌥⌘→ |
| Up | ⌃⌥⌘↑ |
| Down | ⌃⌥⌘↓ |
| Upper Left | ⌃⌥⇧← |
| Upper Right | ⌃⌥⇧↑ |
| Lower Left | ⌃⌥⇧↓ |
| Lower Right | ⌃⌥⇧→ |
| Maximize | ⌃⌥⌘M |
| Center | ⌃⌥⌘C |
| Previous Monitor | ⌃⌥← |
| Next Monitor | ⌃⌥→ |
| SnapBack | ⌃⌥⌘/ |

A held shortcut key performs one action. Release and press again for a second action.
Left/Right and the four corner actions use the configured dividers, margins, and gaps.
**Maximize** fills the usable desktop; it does not create a macOS full-screen Space.

## Center with two side windows

Choose the desired display in Preferences → Window Sizes, enabling separate display
settings if needed. Configure Center's width and height, then enable Alternate Left
and Alternate Right. Use manual side widths or **Fit beside Center** and choose Apply.

For example, a 60%-wide Center with 20%-wide sides fills the available width when
margins and gaps are zero. A 50% Center with 25% sides is another option. Every value
is configurable; manual side widths need not sum with Center to 100%. Center can
also be shorter than the desktop, and either side can use a fixed point width.

To arrange the windows:

1. Focus your main window and press Center.
2. Focus the left-side app and press Left. It moves to the normal split. Press Left
   again to use its alternate width.
3. Focus the right-side app and press Right twice to reach its alternate width.

If a window is already at its normal split, the next matching action goes directly
to the alternate. There is no timing requirement. Switching focus and coming back
does not reset the cycle. Moving or resizing a window away from its normal region
makes the next Left or Right use the normal split again.

For an ultrawide and a laptop, use separate profiles: for example, enable narrow
alternate sides on the ultrawide and leave them disabled on the laptop. Fit beside
Center adjusts side regions when you change Center's configured width or horizontal
gap; apply the actions again to move existing windows to the revised layout.

## Move between monitors

Previous Monitor and Next Monitor move the focused window through the available
macOS display order, wrapping at either end. With one display, they leave it where
it is. Monitor transfers preserve relative placement and, by default, scale the
window proportionally to the destination's usable area.

Turn off proportional resizing in Advanced to retain the window's size where it
fits. Destination margins and bounds handling still apply. Layout commands on the
new display use that display's saved profile.

## SnapBack

SnapBack restores a window to the position and size it had before the first
successful change in its current sequence. You can go from Left to an alternate
width, move to another monitor, then SnapBack to the starting frame.

Each window has its own baseline. A successful restore clears it; the next change
starts a new sequence. SnapBack with no baseline leaves the window alone. If the
original monitor is missing, restoration uses the current display and keeps the
window accessible where possible. A failed restore retains its baseline for retry.

SnapBack history lives only in the running app. Quitting PaneGlide clears it; it is
not included in settings exports.

## Menu and preferences

The menu offers the same positioning actions, shortcut enable/disable, Preferences,
View on GitHub, Accessibility help, Help, About, and Quit. Hidden actions can be
restored through the Shortcuts tab's **Show in menu** controls. **Help…** opens this
usage guide in your browser. Successful moves are silent. If a command fails, its
explanation appears at the top of the menu and clears after the next successful
menu or shortcut action.

To stop shortcuts temporarily, choose **Disable Shortcuts** in the menu. Menu and
AppleScript actions still work. To stop the utility, choose **Quit PaneGlide**.
Reopening PaneGlide from Finder shows Preferences, including when its icon is hidden.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No window moves | Check the Accessibility status in General; follow [access setup](installation.md#enable-accessibility) if needed |
| A shortcut does nothing or reports a conflict | Enable shortcuts; quit competing window utilities or assign a different binding, then Apply |
| Left/Right always uses the normal split | Enable the alternate for the current display, Apply, then release and press the same shortcut again |
| A window does not fit the requested region | The app may enforce a minimum size, aspect ratio, or resize increment; try a wider region or adjust Advanced options |
| A window cannot be positioned | Select an ordinary, unminimized window and exit native full-screen mode; dialogs and some app windows are unsupported |
| Changes disappear when Preferences closes | Choose Apply to save edits; the login switch takes effect immediately |
| A monitor uses unexpected sizes | Check Display settings and whether that monitor has a separate profile |
| The menu icon is missing | Reopen PaneGlide from Finder and enable Show PaneGlide in menu bar, then Apply |

PaneGlide does not move windows between macOS Spaces. It positions windows on the
available displays and can arrange multiple windows through [AppleScript](scripting.md).
