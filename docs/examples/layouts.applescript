-- Run one example at a time. Switch to the target window during the delay.
-- Positions and sizes use logical macOS points.
delay 3
tell application "PaneGlide"
    do action Center

    -- Normal Left, then its alternate width when enabled:
    -- do action Left
    -- do action Left
    -- do action SnapBack

    -- Other individual layouts:
    -- do action Third Center
    -- do action Move Upper Right
    -- move to {40, 60}
    -- resize to {800, 600}
    -- move and resize to {40, 60, 800, 600}
    -- fit to grid {1, 0, 2, 3} grid size {4, 3}

    -- These require the referenced monitor to be connected:
    -- do action Center on monitor 2
    -- send to monitor 1
end tell
