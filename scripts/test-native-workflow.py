#!/usr/bin/env python3
"""Native three-window layouts and identity, using only disposable fixture windows."""
import json
import re
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parent.parent
fixture = root / ".build/WindowFixture.app"
app = root / "dist/PaneGlide.app/Contents/MacOS/PaneGlide"
def foreground():
    return subprocess.check_output(["/usr/bin/swift", "-module-cache-path", str(root / ".build/ModuleCache"), "-e", 'import AppKit; print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")'], text=True).strip()
if foreground() == "com.apple.loginwindow":
    raise SystemExit("BLOCKED: unlock the Mac before native workflow acceptance.")
pattern = "^" + re.escape(str(fixture / "Contents/MacOS/WindowFixture")) + "( |$)"
existing = subprocess.run(["/usr/bin/pgrep", "-f", pattern], capture_output=True, text=True)
for pid in existing.stdout.split():
    subprocess.run(["/bin/kill", "-TERM", pid], check=True)
subprocess.run(["/usr/bin/open", "-n", str(fixture), "--args", "--multiple"], check=True)
time.sleep(0.8)
if foreground() != "com.jpwinans.size-up.fixture":
    raise SystemExit("BLOCKED: disposable fixture did not become frontmost.")
metadata = Path("/private/tmp/paneglide-fixture.json")
before = json.loads(metadata.read_text())
report_path = Path("/private/tmp/paneglide-workflow-test.json")
if report_path.exists():
    report_path.unlink()
subprocess.run([str(app), "--integration-workflow-test"], check=True, timeout=30)
report = json.loads(report_path.read_text())
after = json.loads(metadata.read_text())
report["fixtureBefore"] = before
report["fixtureAfter"] = after
(root / ".build/native-workflow-result.json").write_text(json.dumps(report, indent=2) + "\n")
assert report.get("passed"), report.get("error", "Incomplete workflow run")
assert len(report["cases"]) == 5
assert report["renameRestored"] and report["closedIdentityRejected"] and report["replacementUnaffected"]
old = {w["number"]: w["frame"] for w in before["windows"]}
new = {w["number"]: w["frame"] for w in after["windows"]}
assert len(old.keys() & new.keys()) == 3, "Exactly one test window should have been replaced"
assert all(old[n] == new[n] for n in old.keys() & new.keys()), "A surviving window was not independently restored"
assert before["frame"] == after["frame"]
print("PASS: five configurable three-window layouts; independent restoration; untouched fourth window; rename and close/reopen identity.")
