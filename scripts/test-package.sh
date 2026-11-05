#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
package_test_root="$(mktemp -d "${TMPDIR:-/tmp}/paneglide-package-test.XXXXXX")"
trap 'rm -rf "$package_test_root"' EXIT
mkdir -p "$package_test_root/scripts" "$package_test_root/Resources" "$package_test_root/dist"
cp scripts/package-release.sh "$package_test_root/scripts/"
cp LICENSE "$package_test_root/"
printf 'dist/\n' > "$package_test_root/.gitignore"
printf 'PaneGlide fixture source\n' > "$package_test_root/README.md"
printf 'Never include build output\n' > "$package_test_root/dist/private.txt"
/usr/bin/python3 - "$package_test_root" <<'PY'
from pathlib import Path
import plistlib, sys
p=Path(sys.argv[1])/'Resources/Info.plist'
p.write_bytes(plistlib.dumps({'CFBundleShortVersionString':'1.2.3','CFBundleVersion':'1.2.3'}))
PY
git -C "$package_test_root" init -q
git -C "$package_test_root" add .
git -C "$package_test_root" -c user.name='Package Test' -c user.email='test@example.invalid' commit -qm 'Fixture source'
env -u CODE_SIGN_IDENTITY -u NOTARYTOOL_PROFILE -u PANEGLIDE_VERSION bash "$package_test_root/scripts/package-release.sh"
/usr/bin/python3 - "$package_test_root" <<'PY'
from pathlib import Path
import hashlib, sys, zipfile
p=Path(sys.argv[1]); archive=p/'dist/PaneGlide-source.zip'
with zipfile.ZipFile(archive) as z:
    assert z.read('PaneGlide-1.2.3/README.md') == b'PaneGlide fixture source\n'
    assert 'PaneGlide-1.2.3/LICENSE' in z.namelist()
    assert not any('/dist/' in name or '/.git/' in name for name in z.namelist())
checksum=(p/'dist/SHA256SUMS.txt').read_text().split()
assert checksum == [hashlib.sha256(archive.read_bytes()).hexdigest(), 'PaneGlide-source.zip']
assert not (p/'dist/PaneGlide.zip').exists()
PY
echo 'PASS: clean committed source produces a matching versioned archive and checksum without credentials.'
printf 'Uncommitted change\n' >> "$package_test_root/README.md"
cp "$package_test_root/dist/PaneGlide-source.zip" "$package_test_root/before.zip"
if bash "$package_test_root/scripts/package-release.sh" > "$package_test_root/dirty.log" 2>&1; then
    echo 'FAIL: packaging accepted uncommitted source.' >&2; exit 1
fi
cmp "$package_test_root/before.zip" "$package_test_root/dist/PaneGlide-source.zip"
grep -q 'Commit all source changes' "$package_test_root/dirty.log"
echo 'PASS: uncommitted source is rejected and the previous archive remains intact.'
