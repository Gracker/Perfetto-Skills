import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.sync_official_skill import (
    build_gap_report,
    inventory_official_skill,
    load_reviewed_decisions,
)


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
        report = build_gap_report(previous, current, {})
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
        decision = {
            "outcome": "adopted",
            "reason": "Implemented by the portable runtime",
            "local_path": "scripts/example.py",
            "test_id": "test-example",
            "reviewed_source_commit": "c" * 40,
        }
        report = build_gap_report(
            {"files": [{"path": path, "sha256": "a" * 64}]},
            {"files": [{"path": path, "sha256": "b" * 64}]},
            {(path, "b" * 64): decision},
        )
        self.assertEqual(report["unresolved"], [])
        self.assertEqual(report["classifications"][0]["outcome"], "adopted")
        self.assertEqual(report["classifications"][0]["test_id"], "test-example")

    def test_unchanged_file_without_exact_decision_stays_pending(self) -> None:
        path = "ai/skills/perfetto/workflows/android_memory/new.md"
        snapshot = {"files": [{"path": path, "sha256": "a" * 64}]}
        report = build_gap_report(snapshot, snapshot, {})
        self.assertEqual(
            report["classifications"],
            [{"path": path, "sha256": "a" * 64, "outcome": "pending_review"}],
        )
        self.assertEqual(report["unresolved"], [path])

    def test_exact_hash_decision_applies_with_evidence(self) -> None:
        path = "ai/skills/perfetto/workflows/android_memory/new.md"
        snapshot = {"files": [{"path": path, "sha256": "a" * 64}]}
        decision = {
            "outcome": "already_covered",
            "reason": "Implemented as deterministic SmartPerfetto evidence",
            "local_path": "backend/skills/composite/example.skill.yaml",
            "test_id": "execute-example",
            "reviewed_source_commit": "b" * 40,
        }
        report = build_gap_report(snapshot, snapshot, {(path, "a" * 64): decision})
        self.assertEqual(
            report["classifications"][0],
            {"path": path, "sha256": "a" * 64, **decision},
        )
        self.assertEqual(report["unresolved"], [])

    def test_decision_registry_rejects_missing_coverage_evidence(self) -> None:
        decision = {
            "path": "ai/skills/perfetto/SKILL-template.md",
            "sha256": "a" * 64,
            "outcome": "already_covered",
            "reason": "Covered",
        }
        with tempfile.TemporaryDirectory() as temporary:
            registry = Path(temporary) / "decisions.json"
            registry.write_text(
                json.dumps({"schema_version": 1, "decisions": [decision]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "reviewed decision"):
                load_reviewed_decisions(registry)

    def test_decision_registry_rejects_unknown_keys(self) -> None:
        decision = {
            "path": "ai/skills/perfetto/SKILL-template.md",
            "sha256": "a" * 64,
            "outcome": "not_applicable",
            "reason": "No portable runtime behavior",
            "unexpected": True,
        }
        with tempfile.TemporaryDirectory() as temporary:
            registry = Path(temporary) / "decisions.json"
            registry.write_text(
                json.dumps({"schema_version": 1, "decisions": [decision]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "reviewed decision"):
                load_reviewed_decisions(registry)


if __name__ == "__main__":
    unittest.main()
