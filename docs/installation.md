# Install PaneGlide

PaneGlide is distributed as source code and builds on your Mac. You need an Apple
silicon Mac running **macOS 14 or later**, Apple's free developer tools with
**Swift 6 or later**, and a few commands in Terminal. No paid developer account or
Apple distribution certificate is needed.

## Download and install

1. [Download the source ZIP](https://github.com/jpwinans/paneglide/releases/latest/download/PaneGlide-source.zip)
   and double-click it in Finder to extract it.
2. Open **Terminal** from Applications → Utilities. If you do not already have
   Apple's developer tools, run this command and finish the installation dialog:

   ```sh
   xcode-select --install
   ```

   The current Command Line Tools are sufficient. Xcode 16 or later also works.
   The installer checks that your selected tools include Swift 6 and the macOS SDK.
3. In Terminal, type `cd ` (including the space), drag the extracted PaneGlide folder
   from Finder into Terminal, and press Return. Then run:

   ```sh
   bash install.sh
   ```

4. Wait for **Installed PaneGlide**. The app opens **Quick Start**, which guides you
   through Accessibility access and optional startup at login.

The installer builds the app, checks its local signature and Apple silicon code,
and puts **PaneGlide.app** in the Applications folder inside your home folder
(`~/Applications`). It does not need administrator access. Keep the app there so
startup and upgrades use the same location. You can delete the downloaded source
folder after installation; the installed app does not depend on it.

PaneGlide lives in the menu bar and does not keep a Dock icon. Quit other window
managers or disable their matching shortcuts before using PaneGlide.

## Enable Accessibility

1. In Quick Start, choose **Open Accessibility Settings…**.
2. In System Settings → Privacy & Security → Accessibility, enable **PaneGlide**.
   If it is not listed, click **+** and select your installed PaneGlide.app.
   **Show App in Finder** helps you locate that exact copy.
3. Return to Quick Start. Its status should read **Accessibility access is enabled**.
4. Choose **Start Using PaneGlide**. Focus a normal window in another app, then press
   **Control–Option–Command–Left**. Press **Control–Option–Command–/** to restore it.

You can reopen Quick Start from the menu at any time. Help includes **Edit Shortcuts…**,
which opens the shortcut editor directly. PaneGlide does not need Screen Recording
permission. [Privacy](privacy.md) explains what it accesses and stores.

Local builds use an ad-hoc signature. After a rebuild or update, macOS may require
an Accessibility refresh: quit and reopen PaneGlide first. If Quick Start still
reports no access, remove **PaneGlide** from the Accessibility list, add the
installed copy again, and enable it. You do not need to change permissions for any
other application or disable macOS security protections.

## Start at login

Enable **Start PaneGlide automatically at login** in Quick Start or Preferences →
General. This switch takes effect immediately, without Apply. If macOS requires
approval, use **Open Login Items Settings…** and approve PaneGlide there.

Leave **Show preferences on launch** off to start quietly in the menu bar. Changes
to that option require **Apply**. Open PaneGlide from Finder to return to Preferences
when the menu icon is hidden; if Help is already open, use its Preferences button.

## Update

Download the latest source ZIP, extract it, open Terminal in that new folder, and
run the same command:

```sh
bash install.sh
```

The installer finishes building before stopping the installed app. It replaces
the complete app, opens the new copy, and leaves your saved settings intact. Apply
or discard any pending Preferences edits before updating. SnapBack history clears
when the app restarts.

A ZIP of the previous app is kept in `~/Applications/.PaneGlide Backups/`. To find
that hidden folder in Finder, use **Go → Go to Folder…** and paste the path. To
restore a backup, extract its ZIP, quit PaneGlide, and use Finder to replace the
current app with the extracted copy. Keep the same installation location. This
restores the app; it does not roll back your settings. Use **Export Saved Settings…**
if you also want a configuration backup. Old app backups can be deleted when you
no longer need them.

PaneGlide has no built-in updater. Use **View on GitHub…** for new releases.

## Troubleshooting installation

| Message or problem | What to do |
| --- | --- |
| `install.sh` cannot be found | Open Terminal in the extracted folder containing `install.sh`; use the `cd ` and drag step above |
| Developer tools are missing | Run `xcode-select --install`, finish the dialog, then retry |
| Swift 6 or later is required | Update Command Line Tools in System Settings → General → Software Update, or install Xcode 16+ and select its Command Line Tools in Xcode → Settings → Locations |
| Xcode setup or license is incomplete | Open Xcode and complete its setup, then retry |
| The app is already installed | Run the installer normally; it backs up and replaces the existing PaneGlide app |
| Another app occupies the destination | Move or rename that unrelated app, or choose another Applications folder; the installer will not replace it |
| The app opens but nothing moves | Check Quick Start's Accessibility status and use an ordinary, unminimized window outside macOS Full Screen |
| A build fails | Keep the Terminal error text and include it with your macOS and Swift versions in a [support request](../SUPPORT.md) |

Apple documents [installing the Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools).
For runtime issues, see [troubleshooting](usage.md#troubleshooting).

## Other installation options

For Git users:

```sh
git clone https://github.com/jpwinans/paneglide.git
cd paneglide
bash install.sh
```

This installs the current `main` branch. Release ZIPs provide a fixed released version.

Use `bash install.sh --help` for options. For example:

```sh
bash install.sh --no-launch
bash install.sh --applications-dir "$HOME/Applications"
```

Use the same destination on updates. Development builds and optional local signing
are covered in [Contributing](../CONTRIBUTING.md).

## Remove the app

Turn off **Start PaneGlide automatically at login**, choose **Quit PaneGlide**, and
move the app to Trash. Saved settings remain in
`~/Library/Application Support/PaneGlide/` so reinstalling can reuse them. You can
also remove PaneGlide's Accessibility entry in System Settings.

Settings exports do not include macOS startup registration, Accessibility access,
or per-Mac Quick Start completion.
