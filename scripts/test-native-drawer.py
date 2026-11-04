#!/usr/bin/env python3
"""Exercise the public native command boundary with a real legacy NSDrawer."""
import json
import re
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
fixture = root / ".build/WindowFixture.app"
app = root / "dist/PaneGlide.app/Contents/MacOS/PaneGlide"
# Run only after other PaneGlide copies have quit; this debug runner targets the
# fixture by its dedicated bundle ID, never the user's frontmost document.
pattern = "^" + re.escape(str(fixture / "Contents/MacOS/WindowFixture")) + "( |$)"
existing = subprocess.run(["/usr/bin/pgrep", "-f", pattern], capture_output=True, text=True)
for pid in existing.stdout.split():
    subprocess.run(["/bin/kill", "-TERM", pid], check=True)
subprocess.run(["/usr/bin/open", "-n", str(fixture), "--args", "--drawer"], check=True)
time.sleep(0.8)
metadata = Path("/private/tmp/paneglide-fixture.json")
before = json.loads(metadata.read_text())
assert before["frame"] == [150, 150, 700, 532], "Unexpected fixture geometry"
assert before["drawerWindowFrame"] == [844, 165, 196, 485], "Drawer did not open beside the parent"
report_path = Path("/private/tmp/paneglide-native-test.json")
if report_path.exists():
    report_path.unlink()  # This runner owns the disposable diagnostic report.
subprocess.run([str(app), "--integration-test", "--drawer-checks"], check=True, timeout=30)
report = json.loads(report_path.read_text())
after = json.loads(metadata.read_text())
report["fixtureBefore"] = before
report["fixtureAfter"] = after
(root / ".build/native-drawer-result.json").write_text(json.dumps(report, indent=2) + "\n")
assert report.get("trusted"), "Accessibility is required"
assert report.get("drawerInsets") == [0, 0, 0, 190], "The real drawer's 190-point overhang was not reserved"
assert "error" not in report, "A real window command failed"
primary_top = before["screens"][0]["frame"][1] + before["screens"][0]["frame"][3]
areas = [(s["visible"][0], primary_top - s["visible"][1] - s["visible"][3], s["visible"][2], s["visible"][3]) for s in before["screens"]]
for result in report["results"]:
    assert result["drawerInsets"] == [0, 0, 0, 190], "Drawer geometry was lost during a command"
    actual = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", result["actual"])]
    assert any(actual[0] >= x - 1 and actual[1] >= y - 1 and actual[0] + actual[2] + 190 <= x + w + 1 and actual[1] + actual[3] <= y + h + 1 for x, y, w, h in areas), "Combined parent/drawer escaped the usable desktop"
    if result["constrained"]:
        # A narrow laptop column can leave less room than AppKit's minimum
        # parent width after reserving the drawer. Report that real constraint.
        requested = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", result["expected"])]
        assert actual[2] > requested[2] and abs(actual[3] - requested[3]) <= 1, result
assert report.get("restored") and after["frame"] == before["frame"], "The original parent frame was not restored"
assert len(report["results"]) == 28 * report["displayCount"], "Incomplete command sequence"
closed, ignored, reserved = report["drawerPhases"]
assert closed["drawerInsets"] == [0, 0, 0, 0], "Closed drawer retained a stale inset"
assert ignored["drawerInsets"] == reserved["drawerInsets"] == [0, 0, 0, 190], "Reopened drawer was not discovered"
assert closed["actual"] == ignored["actual"], "Disabling drawer accounting changed the parent layout"
assert ignored["actual"][2] - reserved["actual"][2] == 190, "Enabled accounting did not reserve the overhang"
assert ignored["actual"][:2] == reserved["actual"][:2] and ignored["actual"][3] == reserved["actual"][3]
print(f"PASS: {len(report['results'])} commands plus close/reopen/toggle checks reserve the real drawer and restore the parent.")
