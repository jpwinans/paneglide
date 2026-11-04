# AppleScript

Address the installed app as `PaneGlide`. Open its dictionary
in Script Editor to browse the commands. Window commands act on the frontmost
application's window, so do not activate PaneGlide before issuing them.

When trying a script from Script Editor, add a delay and switch to the intended
window before the command runs:

```applescript
delay 3
tell application "PaneGlide"
    do action Center
end tell
```

PaneGlide needs Accessibility access. macOS may separately ask for Automation permission
for the script host to address PaneGlide. See [layout examples](examples/layouts.applescript)
and [batch examples](examples/batch.applescript); select one example at a time.

## Actions

`do action` accepts these names:

| Group | Actions |
| --- | --- |
| Split | `Left`, `Right`, `Up`, `Down` |
| Corners | `Upper Left`, `Upper Right`, `Lower Left`, `Lower Right` |
| Size and restore | `Full Screen`, `Center`, `SnapBack` |
| Displays | `Prev Monitor`, `Next Monitor` |
| Move without resizing | `Move Left`, `Move Right`, `Move Up`, `Move Down`, `Move Upper Left`, `Move Upper Right`, `Move Lower Left`, `Move Lower Right`, `Move Center` |
| Thirds | `Third Left`, `Third Center`, `Third Right`, `Third Upper`, `Third Middle`, `Third Lower` |

Left and Right honor the same alternate-width settings as shortcuts and menu actions.
Use `on monitor n` to apply a layout on a specified display. Monitor indexes start at
one and follow the current macOS display order. `send to monitor n` transfers the
window using the proportional-sizing and bounds preferences.

```applescript
tell application "PaneGlide"
    do action Left on monitor 1
    -- Other individual examples:
    -- send to monitor 2
    -- do action SnapBack
end tell
```

## Explicit geometry

| Command | Meaning |
| --- | --- |
| `move to {x, y}` | Move without changing size |
| `resize to {width, height}` | Resize without explicitly changing position |
| `move and resize to {x, y, width, height}` | Set position and dimensions |
| `fit to grid {column, row, width, height} grid size {columns, rows}` | Fill a region of a grid |

These commands also accept `on monitor n`. Explicit positions are relative to the
selected display's usable desktop after enabled edge margins. Dimensions are logical
macOS points. Grid cells start at zero, must use whole numbers, and must fit inside
the grid. The default grid size is 6×6. Grid layouts honor partition gaps.

Window commands return the actual absolute desktop frame as
`{x, y, width, height}`, with the origin at the top left. Returned values can differ
from the request when an app limits its size or bounds handling adjusts the result.
SnapBack applies to scripted changes too.

## Arrange multiple windows

```applescript
tell application "PaneGlide"
    tile windows
    -- Alternatives:
    -- cascade windows
    -- tile windows on monitor 1 all applications true
end tell
```

Tile and Cascade use visible, normal windows of the frontmost application on its
current display. `on monitor n` selects another display. `all applications true`
explicitly includes other apps' eligible windows on that display. Each changed window
keeps an independent SnapBack baseline.

Tile uses a grid with roughly equal row and column counts. Cascade uses 75% of the
available width and height with 24-point offsets. Both return a list of actual frames.
App minimum sizes can prevent perfect tiling. If some windows fail, the command
reports an error with the number already arranged.

Batch commands support up to 64 eligible windows. Hidden, minimized, native-full-screen,
and ambiguous same-frame windows are skipped. No Screen Recording permission or
window content inspection is needed.

## App controls and errors

- `enabled` gets or sets global shortcut enablement. Menu and script actions remain
  available while it is false.
- `name`, `version`, and `frontmost` are readable properties.
- `show menu` opens the status menu when its icon is enabled.

Invalid arguments, missing access, unsupported targets, and closed or unresponsive
windows produce AppleScript errors. The same geometry and constraint preferences
apply to scripts as to shortcuts. Commands for moving between Spaces are not provided.
