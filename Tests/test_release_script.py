"""Release orchestration tests. Xcode is stubbed; no signing or upload occurs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rally-release-tests-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copy2(ROOT / "ship.sh", self.root / "ship.sh")
        (self.root / "Rally.xcodeproj").mkdir()
        (self.root / "Rally.xcodeproj/project.pbxproj").touch()
        (self.root / "Config").mkdir()
        shutil.copy2(ROOT / "Config/ExportOptions-TestFlight.plist", self.root / "Config")
        (self.root / "Config/Local.xcconfig").write_text("keep existing signing\n")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        mock = self.bin / "xcodebuild"
        mock.write_text('''#!/bin/bash
set -eu
printf '%s\\n' "$*" >> "$CALLS"
if [ "$1" = '-version' ]; then echo 'Xcode test fixture'; exit 0; fi
if [ "$1" = '-sdk' ]; then echo "${TEST_SDK:-26.0}"; exit 0; fi
mode="$1"
shift
archive=''
export_dir=''
options=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -archivePath) archive="$2"; shift ;;
    -exportPath) export_dir="$2"; shift ;;
    -exportOptionsPlist) options="$2"; shift ;;
  esac
  shift
done
if [ "$mode" = archive ]; then
  mkdir -p "$archive/Products/Applications/Rally.app"
  if [ "${INCOMPLETE:-0}" = 0 ]; then touch "$archive/Info.plist"; fi
  exit "${ARCHIVE_EXIT:-0}"
fi
if [ "$mode" = '-exportArchive' ]; then
  cp "$options" "$EXPORTED_OPTIONS"
  mkdir -p "$export_dir"
  touch "$export_dir/Rally.ipa"
  exit "${EXPORT_EXIT:-0}"
fi
exit 99
''')
        mock.chmod(0o755)
        self.env = dict(os.environ)
        for name in ("TEAM_ID", "BUILD_NUMBER", "ASC_KEY_PATH", "ASC_KEY_ID", "ASC_ISSUER_ID"):
            self.env.pop(name, None)
        self.env.update(PATH=f"{self.bin}:{os.environ['PATH']}",
                        CALLS=str(self.root / "calls"),
                        EXPORTED_OPTIONS=str(self.root / "exported.plist"),
                        BUILD_NUMBER="1")

    def run_script(self, *args, **env):
        return subprocess.run(["/bin/bash", str(self.root / "ship.sh"), *args],
                              env=dict(self.env, **env), capture_output=True, text=True)

    def calls(self):
        path = self.root / "calls"
        return path.read_text() if path.exists() else ""

    def test_default_only_checks(self):
        self.assertEqual(self.run_script().returncode, 0)
        self.assertNotIn("archive", self.calls())
        self.assertFalse((self.root / "build").exists())

    def test_old_sdk_cannot_upload(self):
        self.assertNotEqual(self.run_script("--upload", TEST_SDK="18.5").returncode, 0)
        self.assertNotIn("archive", self.calls())

    def test_typo_does_not_upload(self):
        self.assertEqual(self.run_script("--uplod").returncode, 2)
        self.assertEqual(self.calls(), "")

    def test_archive_failure_never_exports_even_with_partial_output(self):
        self.assertNotEqual(self.run_script("--upload", ARCHIVE_EXIT="65").returncode, 0)
        self.assertNotIn("-exportArchive", self.calls())

    def test_incomplete_archive_never_exports(self):
        self.assertNotEqual(self.run_script("--upload", INCOMPLETE="1").returncode, 0)
        self.assertNotIn("-exportArchive", self.calls())

    def test_archive_only_preserves_settings_and_prior_runs(self):
        for _ in range(2):
            self.assertEqual(self.run_script("--archive").returncode, 0)
        self.assertEqual(len(list((self.root / "build").glob("release-*"))), 2)
        self.assertNotIn("-exportArchive", self.calls())
        self.assertEqual((self.root / "Config/Local.xcconfig").read_text(), "keep existing signing\n")

    def test_ipa_exports_without_upload_destination(self):
        import plistlib
        self.assertEqual(self.run_script("--ipa").returncode, 0)
        with (self.root / "exported.plist").open("rb") as file:
            options = plistlib.load(file)
        self.assertEqual(options["destination"], "export")
        self.assertEqual(options["teamID"], "832KFP5M8B")

    def test_explicit_upload_and_failed_export(self):
        import plistlib
        self.assertEqual(self.run_script("--upload").returncode, 0)
        with (self.root / "exported.plist").open("rb") as file:
            self.assertEqual(plistlib.load(file)["destination"], "upload")
        self.assertNotEqual(self.run_script("--upload", EXPORT_EXIT="70").returncode, 0)

    def test_bad_build_number_and_partial_credentials_stop_before_archive(self):
        self.assertNotEqual(self.run_script("--upload", BUILD_NUMBER="202610071900").returncode, 0)
        self.assertNotEqual(self.run_script("--upload", ASC_KEY_ID="partial").returncode, 0)
        self.assertNotIn("-exportArchive", self.calls())
        self.assertFalse((self.root / "build").exists())


if __name__ == "__main__":
    unittest.main()
