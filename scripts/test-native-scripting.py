#!/usr/bin/env python3
"""Requires one running PaneGlide build and a built, disposable WindowFixture.app."""
import json
import re
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
fixture = root / ".build/WindowFixture.app"
if not fixture.is_dir():
    raise SystemExit("Build the disposable fixture with scripts/build-fixture.sh first.")
def foreground_app():
    # Read-only precondition: never send window commands to a lock screen or to
    # another app when launch activation did not focus the disposable fixture.
    return subprocess.check_output([
        "/usr/bin/swift", "-module-cache-path", str(root / ".build/ModuleCache"), "-e",
        'import AppKit; print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")'
    ], text=True).strip()

if foreground_app() == "com.apple.loginwindow":
    raise SystemExit("BLOCKED: unlock the Mac before running foreground-window acceptance.")
pattern = "^" + re.escape(str(fixture / "Contents/MacOS/WindowFixture")) + "( |$)"
existing = subprocess.run(["/usr/bin/pgrep", "-f", pattern], capture_output=True, text=True)
for pid in existing.stdout.split():
    subprocess.run(["/bin/kill", "-TERM", pid], check=True)
subprocess.run(["/usr/bin/open", "-n", str(fixture)], check=True)
time.sleep(0.8)
if foreground_app() != "com.jpwinans.size-up.fixture":
    raise SystemExit("BLOCKED: the disposable fixture is not the foreground app; no window commands were sent.")
metadata = Path("/private/tmp/paneglide-fixture.json")
before = json.loads(metadata.read_text())["frame"]
result = subprocess.run(["/usr/bin/osascript", "-s", "s", str(root / "Tests/Native/scripting.applescript")], capture_output=True, text=True, timeout=30)
after = json.loads(metadata.read_text())["frame"]
report = {"exit": result.returncode, "beforeAppKit": before, "afterAppKit": after,
          "output": result.stdout.strip(), "error": result.stderr.strip(), "restored": before == after}
(root / ".build/native-scripting-result.json").write_text(json.dumps(report, indent=2) + "\n")
if result.returncode != 0 or before != after:
    raise SystemExit("FAIL: " + json.dumps(report))
frames = json.loads(result.stdout.replace("{", "[").replace("}", "]"))
assert len(frames) == 36, "Some script actions did not return a result"
assert len(frames[32][0]) == 4 and len(frames[33][0]) == 4, "Invalid batch rectangles"
print("PASS: 36 script commands returned values; Maximize alias verified; point/rectangle and batch assertions passed; baseline restored.")
