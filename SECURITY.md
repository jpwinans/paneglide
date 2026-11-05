# Security

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/jpwinans/paneglide/security/advisories/new)
for security issues. Include the affected PaneGlide and macOS versions, a description
of the impact, and minimal steps or a proof of concept. Keep credentials and personal
data out of the report. Please avoid publishing exploit details in a public issue
before a fix can be coordinated.

Security fixes target the latest stable release. When reporting an older version,
include whether the issue also affects the current release.

## Permissions and data

PaneGlide uses macOS Accessibility access to identify, move, and resize application
windows. AppleScript hosts may also need macOS Automation permission to address it.
It has no account system, telemetry, or in-app updater. See [Privacy](docs/privacy.md)
for local storage and window-data handling.

Development builds are for local use. Public app binaries require Developer ID
signing and notarization; source-only releases are labeled as such. Signing keys
and notarization credentials are never part of the repository.
