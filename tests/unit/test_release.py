import hashlib
import json
from pathlib import Path
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
                Path(temporary), "0.1.0"
            )
            self.assertTrue(checksums.is_file())
            with zipfile.ZipFile(zip_path) as bundle:
                names = set(bundle.namelist())
                provenance = json.loads(bundle.read("PROVENANCE.json"))
            self.assertIn("perfetto-performance-analysis/SKILL.md", names)
            self.assertIn("perfetto-performance-analysis/references/generated/catalog.json", names)
            self.assertIn("LICENSE", names)
            self.assertIn("NOTICE", names)
            self.assertEqual(provenance["version"], "0.1.0")
            self.assertFalse(any(name.endswith(("trace_processor_shell", ".exe")) for name in names))
            with tarfile.open(tar_path, "r:gz") as bundle:
                self.assertEqual(names, {member.name for member in bundle.getmembers() if member.isfile()})

    def test_two_builds_are_byte_for_byte_reproducible(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_paths = build_release.build_release(Path(first), "0.1.0")
            second_paths = build_release.build_release(Path(second), "0.1.0")
            self.assertEqual(
                [sha256(path) for path in first_paths],
                [sha256(path) for path in second_paths],
            )

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


if __name__ == "__main__":
    unittest.main()
