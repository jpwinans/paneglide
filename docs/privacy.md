# Privacy

PaneGlide arranges windows locally on your Mac. It has no accounts, analytics,
advertising, background update checks, or application network service.

## Window access

Accessibility access lets PaneGlide identify the focused window, inspect the window
and display metadata needed for positioning, and set its position and size. Batch
AppleScript commands can enumerate eligible windows on a display. PaneGlide does
not take screenshots or read document contents, and it does not require Screen
Recording permission.

Global shortcut registration is handled by macOS. PaneGlide does not record a
history of typed text. Shortcut recording in Preferences captures the combination
you choose for an action.

## Local storage

Preferences, shortcuts, and display profiles are saved in
`~/Library/Application Support/PaneGlide/settings.json`. Settings exports contain
that configuration. An unreadable settings file is preserved as a recovery file
in the same folder.

SnapBack baselines and window references are held in memory and cleared when the
app quits. The Accessibility grant and login registration are managed by macOS;
they are not included in settings exports. A local macOS preference records whether
the app has already explained Accessibility setup.

## External links and reports

Choosing Help or View on GitHub opens GitHub in your browser. That browsing is
subject to GitHub's policies and your browser settings. The app does not upload
window information when opening those links.

GitHub issues are public. Share only the information needed for a support request,
and remove private content from screenshots. See [Security](../SECURITY.md) for
private vulnerability reports.
