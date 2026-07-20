import json
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

    def _lock(self, path: Path, commit: str, trees: dict[str, str]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "schema_version": 2,
                    "repository": ANDROID_SKILLS_REPOSITORY,
                    "role": "gap_check_only",
                    "tracked_ref": "main",
                    "commit": commit,
                    "subtrees": list(TRACKED_SUBTREES),
                    "trees": trees,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )

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

    def test_sync_rejects_forged_pinned_subtree_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, initial_commit = self._repository(root)
            inventory = inventory_android_skills(repo, initial_commit)
            forged_trees = dict(inventory["trees"])
            forged_trees[TRACKED_SUBTREES[0]] = "f" * 40
            upstreams = root / "upstreams"
            lock = upstreams / "android-skills.lock.json"
            self._lock(lock, initial_commit, forged_trees)
            decisions = upstreams / "android-skills-decisions.json"
            decisions.write_text(
                json.dumps({"schema_version": 1, "decisions": []}),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ValueError, "subtree trees differ"):
                main(
                    [
                        "--source",
                        str(repo),
                        "--lock",
                        str(lock),
                        "--decisions",
                        str(decisions),
                        "--report-dir",
                        str(root / "reports"),
                    ]
                )

    def test_apply_refuses_unresolved_change_without_mutating_lock(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, initial_commit = self._repository(root)
            upstreams = root / "upstreams"
            initial_inventory = inventory_android_skills(repo, initial_commit)
            lock = upstreams / "android-skills.lock.json"
            self._lock(lock, initial_commit, initial_inventory["trees"])
            decisions = upstreams / "android-skills-decisions.json"
            decisions.write_text(
                json.dumps({"schema_version": 1, "decisions": []}),
                encoding="utf-8",
            )
            original_lock = lock.read_bytes()
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
            self.assertFalse((upstreams / "snapshots/android-skills").exists())

    def test_apply_updates_only_lock_and_gap_report_without_persisting_upstream_copy(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repo, initial_commit = self._repository(root)
            upstreams = root / "upstreams"
            initial_inventory = inventory_android_skills(repo, initial_commit)
            lock = upstreams / "android-skills.lock.json"
            self._lock(lock, initial_commit, initial_inventory["trees"])

            upstream_marker = "OFFICIAL_UPSTREAM_BODY_MUST_NOT_BE_PERSISTED"
            changed = repo / TRACKED_SUBTREES[0] / "SKILL.md"
            changed.write_text(upstream_marker, encoding="utf-8")
            subprocess.run(
                ["git", "-C", repo, "commit", "-qam", "candidate"], check=True
            )
            candidate = subprocess.run(
                ["git", "-C", repo, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            candidate_inventory = inventory_android_skills(repo, candidate)
            decisions = []
            for item in candidate_inventory["files"]:
                decisions.append(
                    {
                        "path": item["path"],
                        "sha256": item["sha256"],
                        "outcome": "already_covered",
                        "reason": "Local behavior was reviewed independently",
                        "local_path": "skills/perfetto-performance-analysis/SKILL.md",
                        "test_id": "tests.unit.test_android_skills_sync",
                        "reviewed_source_commit": "b" * 40,
                    }
                )
            decisions_path = upstreams / "android-skills-decisions.json"
            decisions_path.write_text(
                json.dumps({"schema_version": 1, "decisions": decisions}),
                encoding="utf-8",
            )

            result = main(
                [
                    "--source",
                    str(repo),
                    "--lock",
                    str(lock),
                    "--decisions",
                    str(decisions_path),
                    "--commit",
                    candidate,
                    "--report-dir",
                    str(root / "reports"),
                    "--apply",
                ]
            )

            self.assertEqual(result, 0)
            self.assertEqual(json.loads(lock.read_text())["commit"], candidate)
            self.assertTrue((upstreams / "reports/android-skills-gap.json").is_file())
            self.assertFalse((upstreams / "snapshots/android-skills").exists())
            persisted = "\n".join(
                path.read_text(encoding="utf-8")
                for path in upstreams.rglob("*")
                if path.is_file()
            )
            self.assertNotIn(upstream_marker, persisted)


if __name__ == "__main__":
    unittest.main()
