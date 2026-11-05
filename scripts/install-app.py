#!/usr/bin/env python3
"""Install a locally built PaneGlide bundle. Called by install.sh."""
import argparse
import ctypes
from datetime import datetime, timezone
import os
from pathlib import Path
import plistlib
import re
import signal
import shutil
import subprocess
import tempfile
import time
import uuid


def validate_app(app):
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "com.jpwinans.size-up" or info.get("CFBundleExecutable") != "PaneGlide":
        raise ValueError("The selected bundle is not PaneGlide.")
    subprocess.run(["/usr/bin/codesign", "--verify", "--strict", str(app)], check=True)
    subprocess.run(["/usr/bin/lipo", "-verify_arch", "arm64", str(app / "Contents/MacOS/PaneGlide")], check=True)
    return info


def stop_installed_app(destination):
    executable = str(destination / "Contents/MacOS/PaneGlide")
    processes = subprocess.check_output(["/bin/ps", "-axo", "pid=,comm="], text=True)
    for line in processes.splitlines():
        fields = line.strip().split(maxsplit=1)
        if len(fields) != 2 or fields[1] != executable:
            continue
        pid = int(fields[0])
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            continue
        for _ in range(50):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.1)
        else:
            raise ValueError("Quit PaneGlide from its menu, then run the installer again.")


def replace_app(staged_app, destination):
    library = ctypes.CDLL(None, use_errno=True)
    swap = library.renamex_np
    swap.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    swap.restype = ctypes.c_int
    if swap(os.fsencode(staged_app), os.fsencode(destination), 2) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--applications-dir", type=Path, required=True)
    parser.add_argument("--no-launch", action="store_true")
    args = parser.parse_args()
    source = args.app.expanduser().resolve()
    applications = args.applications_dir.expanduser().resolve()
    validate_app(source)
    destination = applications / "PaneGlide.app"
    if destination.is_symlink():
        raise ValueError("The destination app is a symbolic link. Choose another Applications folder.")
    previous_info = None
    if destination.exists():
        previous_info = plistlib.loads((destination / "Contents/Info.plist").read_bytes())
        if previous_info.get("CFBundleIdentifier") != "com.jpwinans.size-up":
            raise ValueError("Another app already occupies this location. Choose another Applications folder.")
    applications.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".paneglide-install-", dir=applications))
    try:
        staged_app = staging / "PaneGlide.app"
        subprocess.run(["/usr/bin/ditto", str(source), str(staged_app)], check=True)
        validate_app(staged_app)
        if previous_info is not None:
            backup_directory = applications / ".PaneGlide Backups"
            backup_directory.mkdir(exist_ok=True)
            version = re.sub(r"[^a-zA-Z0-9._-]", "_", str(previous_info.get("CFBundleShortVersionString", "previous")))
            stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
            backup = backup_directory / f"PaneGlide-{version}-{stamp}-{uuid.uuid4().hex[:8]}.zip"
            subprocess.run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(destination), str(backup)], check=True)
            print(f"Previous app backed up to {backup}", flush=True)
            print("Restarting PaneGlide to install the update…", flush=True)
            stop_installed_app(destination)
            replace_app(staged_app, destination)
        else:
            os.rename(staged_app, destination)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    print(f"Installed PaneGlide in {destination}", flush=True)
    if not args.no_launch:
        opened = subprocess.run(["/usr/bin/open", str(destination)])
        if opened.returncode != 0:
            print("The app is installed. Open PaneGlide from Applications to finish setup.")
    else:
        print("Open PaneGlide from Applications to finish setup.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Installation could not finish: {error}")
