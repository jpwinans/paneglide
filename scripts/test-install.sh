#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -d dist/PaneGlide.app ]] || { echo 'Build the app first with scripts/build-app.sh.' >&2; exit 1; }
install_test_root="$(mktemp -d "${TMPDIR:-/tmp}/paneglide-install-test.XXXXXX")"
trap 'rm -rf "$install_test_root"' EXIT
bash install.sh --app "$PWD/dist/PaneGlide.app" --applications-dir "$install_test_root/Applications" --no-launch
codesign --verify --strict "$install_test_root/Applications/PaneGlide.app"
/usr/bin/python3 - "$install_test_root" <<'PY'
from pathlib import Path
import plistlib,sys
app=Path(sys.argv[1])/'Applications/PaneGlide.app'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
assert info['CFBundleIdentifier']=='com.jpwinans.size-up'
assert (app/'Contents/MacOS/PaneGlide').is_file()
assert (app/'Contents/Resources'/info['CFBundleIconFile']).is_file()
assert (app/'Contents/Resources/LICENSE').is_file()
print('PASS: installer creates a complete, valid app in the selected Applications folder.')
PY
printf 'previous installation\n' > "$install_test_root/Applications/PaneGlide.app/Contents/Resources/Previous.txt"
codesign --force --sign - "$install_test_root/Applications/PaneGlide.app" >/dev/null 2>&1
bash install.sh --app "$PWD/dist/PaneGlide.app" --applications-dir "$install_test_root/Applications" --no-launch
/usr/bin/python3 - "$install_test_root" <<'PY'
from pathlib import Path
import subprocess,sys,zipfile
root=Path(sys.argv[1]);app=root/'Applications/PaneGlide.app'
assert not (app/'Contents/Resources/Previous.txt').exists(), 'Old resources survived the update.'
backups=list((root/'Applications/.PaneGlide Backups').glob('*.zip'))
assert len(backups)==1, 'The previous app was not backed up.'
with zipfile.ZipFile(backups[0]) as archive:
    assert archive.read('PaneGlide.app/Contents/Resources/Previous.txt')==b'previous installation\n'
subprocess.run(['/usr/bin/ditto','-x','-k',str(backups[0]),str(root/'Recovered')],check=True)
subprocess.run(['/usr/bin/codesign','--verify','--strict',str(root/'Recovered/PaneGlide.app')],check=True)
print('PASS: updates replace the whole app and leave a restorable previous-version backup.')
PY
/usr/bin/python3 - "$install_test_root" <<'PY'
from pathlib import Path
import plistlib,subprocess,sys
root=Path(sys.argv[1]);other=root/'Other Applications/PaneGlide.app'
(other/'Contents').mkdir(parents=True)
original=plistlib.dumps({'CFBundleIdentifier':'example.unrelated.app'})
(other/'Contents/Info.plist').write_bytes(original)
result=subprocess.run(['bash','install.sh','--app',str(Path.cwd()/'dist/PaneGlide.app'),'--applications-dir',str(other.parent),'--no-launch'],capture_output=True,text=True)
assert result.returncode!=0
assert (other/'Contents/Info.plist').read_bytes()==original
assert not (other.parent/'.PaneGlide Backups').exists()
print('PASS: an unrelated app at the destination is preserved.')
PY

# Exercise the default launch path without starting an app: validation must run first.
if bash install.sh --app "$install_test_root/missing.app" --applications-dir "$install_test_root/Applications" > "$install_test_root/missing.log" 2>&1; then
    echo 'FAIL: installer accepted a missing app.' >&2; exit 1
fi
grep -q 'Installation could not finish:' "$install_test_root/missing.log"
echo 'PASS: default launch mode reports invalid input without starting an app.'
