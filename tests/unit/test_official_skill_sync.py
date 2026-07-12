from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.sync_official_skill import build_gap_report, inventory_official_skill


class OfficialSkillSyncTest(unittest.TestCase):
    def test_inventory_is_deterministic_and_reads_git_revision(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo = Path(temporary)
            subprocess.run(["git", "init", "-q", repo], check=True)
            subprocess.run(["git", "-C", repo, "config", "user.email", "test@example.com"], check=True)
            subprocess.run(["git", "-C", repo, "config", "user.name", "Test"], check=True)
            path = repo / "ai/skills/perfetto/SKILL-template.md"
            path.parent.mkdir(parents=True)
            path.write_text("official", encoding="utf-8")
            subprocess.run(["git", "-C", repo, "add", "."], check=True)
            subprocess.run(["git", "-C", repo, "commit", "-qm", "official"], check=True)
            revision = subprocess.run(
                ["git", "-C", repo, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            first = inventory_official_skill(repo, revision)
            second = inventory_official_skill(repo, revision)
            self.assertEqual(first, second)
            self.assertEqual(first["files"][0]["license"], "Apache-2.0")

    def test_gap_report_never_auto_adopts_unknown_behavior(self) -> None:
        previous = {"files": [{"path": "ai/skills/perfetto/old.md", "sha256": "a"}]}
        current = {
            "files": [
                {"path": "ai/skills/perfetto/old.md", "sha256": "b"},
                {"path": "ai/skills/perfetto/new.md", "sha256": "c"},
            ]
        }
        report = build_gap_report(
            previous,
            current,
            {"ai/skills/perfetto/": "already_covered"},
        )
        self.assertEqual(report["added"], ["ai/skills/perfetto/new.md"])
        self.assertEqual(report["changed"], ["ai/skills/perfetto/old.md"])
        self.assertTrue(
            all(item["outcome"] == "pending_review" for item in report["classifications"])
        )
        self.assertEqual(
            report["unresolved"],
            ["ai/skills/perfetto/new.md", "ai/skills/perfetto/old.md"],
        )

    def test_exact_path_and_hash_review_resolves_changed_content(self) -> None:
        path = "ai/skills/perfetto/SKILL-template.md"
        report = build_gap_report(
            {"files": [{"path": path, "sha256": "a" * 64}]},
            {"files": [{"path": path, "sha256": "b" * 64}]},
            {"ai/skills/perfetto/": "already_covered"},
            {(path, "b" * 64): "adopted"},
        )
        self.assertEqual(report["unresolved"], [])
        self.assertEqual(report["classifications"][0]["outcome"], "adopted")


if __name__ == "__main__":
    unittest.main()
