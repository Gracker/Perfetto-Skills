import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

import yaml

from tools import build_release


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ReleaseTest(unittest.TestCase):
    def test_archives_contain_installable_skill_and_provenance(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            zip_path, tar_path, checksums = build_release.build_release(
                Path(temporary), "0.2.0"
            )
            self.assertTrue(checksums.is_file())
            with zipfile.ZipFile(zip_path) as bundle:
                names = set(bundle.namelist())
                provenance = json.loads(bundle.read("PROVENANCE.json"))
            self.assertIn("perfetto-performance-analysis/SKILL.md", names)
            self.assertIn("perfetto-performance-analysis/references/generated/catalog.json", names)
            self.assertIn("tools/install.py", names)
            self.assertIn("LICENSE", names)
            self.assertIn("NOTICE", names)
            self.assertEqual(provenance["version"], "0.2.0")
            self.assertFalse(any(name.endswith(("trace_processor_shell", ".exe")) for name in names))
            self.assertFalse(
                any(name.endswith((".pftrace", ".perfetto-trace")) for name in names)
            )
            self.assertFalse(any("fixture-pack" in name for name in names))
            with tarfile.open(tar_path, "r:gz") as bundle:
                self.assertEqual(names, {member.name for member in bundle.getmembers() if member.isfile()})

    def test_two_builds_are_byte_for_byte_reproducible(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_paths = build_release.build_release(Path(first), "0.2.0")
            second_paths = build_release.build_release(Path(second), "0.2.0")
            self.assertEqual(
                [sha256(path) for path in first_paths],
                [sha256(path) for path in second_paths],
            )

    def test_archive_installer_installs_extracted_skill(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            zip_path, _, _ = build_release.build_release(root / "dist", "0.2.0")
            extracted = root / "extracted"
            with zipfile.ZipFile(zip_path) as bundle:
                bundle.extractall(extracted)
            destination = root / "installed"
            completed = subprocess.run(
                [sys.executable, str(extracted / "tools" / "install.py"), "--destination", str(destination)],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue((destination / "perfetto-performance-analysis" / "SKILL.md").is_file())

    def test_version_cannot_escape_output_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError):
                build_release.build_release(Path(temporary), "../escape")

    def test_release_version_must_match_skill_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "Skill metadata version"):
                build_release.build_release(Path(temporary), "1.0.0")

    def test_release_rejects_symlinks_inside_skill_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            skill = root / "skill"
            skill.mkdir()
            (skill / "SKILL.md").write_text(
                "---\nmetadata:\n  version: \"0.1.0\"\n---\n",
                encoding="utf-8",
            )
            outside = root / "secret"
            outside.write_text("do not package", encoding="utf-8")
            (skill / "leak").symlink_to(outside)
            with mock.patch.object(build_release, "SKILL_ROOT", skill):
                with self.assertRaisesRegex(ValueError, "symbolic link"):
                    build_release.release_entries("0.1.0")

    def test_workflows_are_valid_and_pin_actions_by_commit(self) -> None:
        root = Path(__file__).resolve().parents[2]
        for path in (root / ".github" / "workflows").glob("*.yml"):
            workflow = yaml.safe_load(path.read_text(encoding="utf-8"))
            self.assertIsInstance(workflow, dict, path)
            for job in workflow["jobs"].values():
                for step in job.get("steps", []):
                    action = step.get("uses")
                    if action:
                        _, separator, revision = action.rpartition("@")
                        self.assertEqual(separator, "@", action)
                        self.assertRegex(revision, r"^[0-9a-f]{40}$", action)

    def test_release_write_permission_is_job_scoped(self) -> None:
        root = Path(__file__).resolve().parents[2]
        workflow = yaml.safe_load(
            (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
        )
        self.assertEqual(workflow["permissions"], {"contents": "read"})
        self.assertEqual(
            workflow["jobs"]["release"]["permissions"], {"contents": "write"}
        )

    def test_normal_workflows_are_independent_and_sync_workflow_is_explicit(self) -> None:
        root = Path(__file__).resolve().parents[2]
        for filename in ("verify.yml", "release.yml"):
            text = (root / ".github" / "workflows" / filename).read_text(encoding="utf-8")
            self.assertNotIn("Gracker/SmartPerfetto", text)
            self.assertNotIn("submodules:", text)
            self.assertIn("uv run python tools/verify.py", text)

        sync = (root / ".github/workflows/upstream-sync.yml").read_text(encoding="utf-8")
        self.assertIn("workflow_dispatch", sync)
        self.assertIn("Gracker/SmartPerfetto", sync)
        self.assertIn("google/perfetto", sync)
        self.assertIn("android/skills", sync)
        self.assertIn("sync_smartperfetto.py", sync)
        self.assertIn("sync_official_skill.py", sync)
        self.assertIn("sync_android_skills.py", sync)
        self.assertIn("sync_perfetto_stdlib.py", sync)
        self.assertNotIn("snapshots/android-skills", sync)
        self.assertIn("/tmp/perfetto-skills-candidate", sync)
        self.assertIn("--apply", sync)
        self.assertIn("tools/compile_skill.py", sync)
        self.assertNotIn('"${{ inputs.smartperfetto_commit }}"', sync)
        self.assertNotIn('"refs/tags/${{ inputs.perfetto_tag }}', sync)
        self.assertIn("actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a", sync)

        canary = (root / ".github/workflows/upstream-canary.yml").read_text(encoding="utf-8")
        self.assertIn("schedule:", canary)
        self.assertIn("continue-on-error: true", canary)
        self.assertIn("--sort=-version:refname", canary)
        self.assertIn("sync_official_skill.py", canary)
        self.assertIn("sync_android_skills.py", canary)
        self.assertIn("sync_perfetto_stdlib.py", canary)
        self.assertIn("--revision", canary)
        self.assertNotIn("git push", canary)


if __name__ == "__main__":
    unittest.main()
