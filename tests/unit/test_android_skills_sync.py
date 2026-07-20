import json
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.sync_android_skills import (
    ANDROID_SKILLS_REPOSITORY,
    TRACKED_SUBTREES,
    build_gap_report,
    inventory_android_skills,
    load_reviewed_decisions,
    main,
)


class AndroidSkillsSyncTest(unittest.TestCase):
    def _repository(self, root: Path) -> tuple[Path, str]:
        repo = root / "android-skills"
        subprocess.run(["git", "init", "-q", repo], check=True)
        subprocess.run(
            ["git", "-C", repo, "config", "user.email", "test@example.com"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", repo, "config", "user.name", "Test"], check=True
        )
        subprocess.run(
            ["git", "-C", repo, "remote", "add", "origin", ANDROID_SKILLS_REPOSITORY],
            check=True,
        )
        for subtree, payload in (
            (TRACKED_SUBTREES[0], "sql"),
            (TRACKED_SUBTREES[1], "analysis"),
        ):
            path = repo / subtree / "SKILL.md"
            path.parent.mkdir(parents=True)
            path.write_text(payload, encoding="utf-8")
        subprocess.run(["git", "-C", repo, "add", "."], check=True)
        subprocess.run(["git", "-C", repo, "commit", "-qm", "skills"], check=True)
        revision = subprocess.run(
            ["git", "-C", repo, "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        return repo, revision

    def test_inventory_is_deterministic_and_pins_each_subtree_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repo, revision = self._repository(Path(temporary))
            first = inventory_android_skills(repo, revision)
            second = inventory_android_skills(repo, revision)

        self.assertEqual(first, second)
        self.assertEqual(first["commit"], revision)
        self.assertEqual(list(first["trees"]), list(TRACKED_SUBTREES))
        self.assertEqual(
            [item["path"] for item in first["files"]],
            [f"{subtree}/SKILL.md" for subtree in TRACKED_SUBTREES],
        )
        self.assertTrue(
            all(item["license"] == "Apache-2.0" for item in first["files"])
        )

    def test_unknown_path_hashes_remain_pending(self) -> None:
        current = {
            "commit": "b" * 40,
            "files": [{"path": "profilers/perfetto-sql/SKILL.md", "sha256": "c" * 64}],
        }
        report = build_gap_report({"commit": "a" * 40, "files": []}, current, {})

        self.assertEqual(report["unresolved"], ["profilers/perfetto-sql/SKILL.md"])
        self.assertEqual(report["classifications"][0]["outcome"], "pending_review")

    def test_exact_review_decision_requires_local_evidence(self) -> None:
        decision = {
            "path": "profilers/perfetto-sql/SKILL.md",
            "sha256": "a" * 64,
            "outcome": "adopted",
            "reason": "Portable validator covers the invariant",
            "local_path": "skills/example.py",
            "test_id": "tests.unit.test_example",
            "reviewed_source_commit": "b" * 40,
        }
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "decisions.json"
            path.write_text(
                json.dumps({"schema_version": 1, "decisions": [decision]}),
                encoding="utf-8",
            )
            loaded = load_reviewed_decisions(path)
            self.assertIn((decision["path"], decision["sha256"]), loaded)
            del decision["test_id"]
            path.write_text(
                json.dumps({"schema_version": 1, "decisions": [decision]}),
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "reviewed decision"):
                load_reviewed_decisions(path)

    def test_apply_refuses_unresolved_change_without_mutating_lock_or_snapshot(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, initial_commit = self._repository(root)
            upstreams = root / "upstreams"
            snapshot = upstreams / "snapshots/android-skills/profilers.json"
            snapshot.parent.mkdir(parents=True)
            initial_inventory = inventory_android_skills(repo, initial_commit)
            snapshot.write_text(
                json.dumps(initial_inventory, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            lock = upstreams / "android-skills.lock.json"
            lock.write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "repository": ANDROID_SKILLS_REPOSITORY,
                        "role": "gap_check_only",
                        "tracked_ref": "main",
                        "commit": initial_commit,
                        "subtrees": list(TRACKED_SUBTREES),
                        "trees": initial_inventory["trees"],
                        "snapshot_path": "snapshots/android-skills/profilers.json",
                        "snapshot_sha256": hashlib.sha256(
                            snapshot.read_bytes()
                        ).hexdigest(),
                    },
                    indent=2,
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            decisions = upstreams / "android-skills-decisions.json"
            decisions.write_text(
                json.dumps({"schema_version": 1, "decisions": []}),
                encoding="utf-8",
            )
            original_lock = lock.read_bytes()
            original_snapshot = snapshot.read_bytes()
            changed = repo / TRACKED_SUBTREES[0] / "SKILL.md"
            changed.write_text("changed", encoding="utf-8")
            subprocess.run(
                ["git", "-C", repo, "commit", "-qam", "changed"], check=True
            )
            candidate = subprocess.run(
                ["git", "-C", repo, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()

            with self.assertRaisesRegex(ValueError, "unresolved review"):
                main(
                    [
                        "--source",
                        str(repo),
                        "--lock",
                        str(lock),
                        "--decisions",
                        str(decisions),
                        "--commit",
                        candidate,
                        "--report-dir",
                        str(root / "reports"),
                        "--apply",
                    ]
                )

            self.assertEqual(lock.read_bytes(), original_lock)
            self.assertEqual(snapshot.read_bytes(), original_snapshot)


if __name__ == "__main__":
    unittest.main()
