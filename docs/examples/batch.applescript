-- Run one example at a time. Switch to the target app during the delay.
-- Default scope: its visible normal windows on the focused window's monitor.
delay 3
tell application "PaneGlide"
    tile windows
    -- cascade windows

    -- Include eligible visible windows from all apps on the chosen monitor:
    -- tile windows on monitor 1 all applications true
    -- cascade windows on monitor 1 all applications true
end tell
