import contextlib
import io
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools import check_cross_repo_impact as impact


class CrossRepositoryImpactTest(unittest.TestCase):
    def run_main(self, arguments: list[str]) -> int:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return impact.main(arguments)

    def test_public_runtime_change_requires_review(self) -> None:
        result = impact.classify(
            "perfetto-skills",
            ["skills/perfetto-performance-analysis/scripts/runtime/executor.py"],
        )
        self.assertTrue(result["review_required"])
        self.assertEqual(result["paired_repository"], "SmartPerfetto")

    def test_all_skill_surfaces_and_dotfiles_are_preserved(self) -> None:
        self.assertTrue(
            impact.classify(
                "perfetto-skills",
                ["./skills/perfetto-performance-analysis/SKILL.md"],
            )["review_required"]
        )
        self.assertTrue(
            impact.classify("smartperfetto", [".claude/rules/skills.md"])[
                "review_required"
            ]
        )
        for path in (
            "perfetto",
            "backend/data/perfettoStdlibSymbols.json",
            "backend/src/services/processIdentity/identityGate.ts",
            "backend/src/services/skillPacks/skillPack.ts",
            "backend/src/services/perfettoStdlibScanner.ts",
            "docs/rendering_pipelines/android.md",
        ):
            self.assertTrue(
                impact.classify("smartperfetto", [path])["review_required"], path
            )

    def test_unsafe_or_absolute_paths_are_rejected(self) -> None:
        for path in ("../outside.sql", "/tmp/outside.sql"):
            with self.subTest(path=path), self.assertRaises(ValueError):
                impact.classify("perfetto-skills", [path])

    def test_public_readme_only_change_is_local(self) -> None:
        result = impact.classify("perfetto-skills", ["README.md"])
        self.assertFalse(result["review_required"])
        self.assertEqual(result["matched_paths"], [])

    def test_triggered_cli_requires_explicit_decision(self) -> None:
        self.assertEqual(
            self.run_main(
                [
                    "--repository",
                    "perfetto-skills",
                    "--path",
                    "src/sql/example.sql",
                ]
            ),
            2,
        )

    def test_required_requires_reason(self) -> None:
        self.assertEqual(
            self.run_main(
                [
                    "--repository",
                    "perfetto-skills",
                    "--path",
                    "src/sql/example.sql",
                    "--decision",
                    "required",
                ]
            ),
            2,
        )

    def test_required_requires_valid_paired_checkout(self) -> None:
        common = [
            "--repository",
            "perfetto-skills",
            "--path",
            "src/sql/example.sql",
            "--decision",
            "required",
            "--reason",
            "portable contract changed",
        ]
        self.assertEqual(self.run_main(common), 2)
        self.assertEqual(
            self.run_main([*common, "--paired-path", "/does/not/exist"]), 2
        )

    def test_required_rejects_syntactic_but_missing_paired_commit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = Path(temporary)
            subprocess.run(["git", "init", "-q", repository], check=True)
            subprocess.run(
                ["git", "-C", repository, "config", "user.email", "test@example.com"],
                check=True,
            )
            subprocess.run(
                ["git", "-C", repository, "config", "user.name", "Test"], check=True
            )
            (repository / "file").write_text("data", encoding="utf-8")
            subprocess.run(["git", "-C", repository, "add", "file"], check=True)
            subprocess.run(["git", "-C", repository, "commit", "-qm", "test"], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    repository,
                    "remote",
                    "add",
                    "origin",
                    "https://github.com/Gracker/SmartPerfetto",
                ],
                check=True,
            )
            with self.assertRaisesRegex(ValueError, "does not exist"):
                impact.evaluate(
                    "perfetto-skills",
                    ["src/sql/example.sql"],
                    decision="required",
                    reason="portable change",
                    paired_path=repository,
                    paired_ref="f" * 40,
                )

    def test_required_accepts_only_paired_checkout_exact_head(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            repository = Path(temporary)
            subprocess.run(["git", "init", "-q", repository], check=True)
            subprocess.run(
                ["git", "-C", repository, "config", "user.email", "test@example.com"],
                check=True,
            )
            subprocess.run(
                ["git", "-C", repository, "config", "user.name", "Test"], check=True
            )
            subprocess.run(
                [
                    "git",
                    "-C",
                    repository,
                    "remote",
                    "add",
                    "origin",
                    "https://github.com/Gracker/SmartPerfetto",
                ],
                check=True,
            )
            (repository / "file").write_text("first", encoding="utf-8")
            subprocess.run(["git", "-C", repository, "add", "file"], check=True)
            subprocess.run(["git", "-C", repository, "commit", "-qm", "first"], check=True)
            previous = subprocess.run(
                ["git", "-C", repository, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            (repository / "file").write_text("second", encoding="utf-8")
            subprocess.run(["git", "-C", repository, "commit", "-qam", "second"], check=True)
            head = subprocess.run(
                ["git", "-C", repository, "rev-parse", "HEAD"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
            arguments = {
                "decision": "required",
                "reason": "portable change",
                "paired_path": repository,
            }
            with self.assertRaisesRegex(ValueError, "must equal paired checkout HEAD"):
                impact.evaluate(
                    "perfetto-skills",
                    ["src/sql/example.sql"],
                    paired_ref=previous,
                    **arguments,
                )
            result = impact.evaluate(
                "perfetto-skills",
                ["src/sql/example.sql"],
                paired_ref=head,
                **arguments,
            )
            self.assertEqual(result["paired_evidence"]["validated_ref"], head)

    def test_not_required_requires_reason(self) -> None:
        self.assertEqual(
            self.run_main(
                [
                    "--repository",
                    "perfetto-skills",
                    "--path",
                    "src/sql/example.sql",
                    "--decision",
                    "not_required",
                ]
            ),
            2,
        )

    def test_deferred_requires_reason_and_handoff(self) -> None:
        common = [
            "--repository",
            "perfetto-skills",
            "--path",
            "src/sql/example.sql",
            "--decision",
            "deferred",
        ]
        self.assertEqual(self.run_main(common), 2)
        self.assertEqual(self.run_main([*common, "--reason", "split rollout"]), 2)
        self.assertEqual(
            self.run_main(
                [
                    *common,
                    "--reason",
                    "split rollout",
                    "--handoff",
                    "issue #123",
                ]
            ),
            0,
        )

    def test_untriggered_change_gets_safe_default(self) -> None:
        result = impact.evaluate("perfetto-skills", ["README.md"])
        self.assertEqual(result["decision"], "not_required")
        self.assertEqual(result["reason"], "no paired-contract paths changed")

    def test_collect_changed_paths_includes_branch_index_worktree_and_untracked(self) -> None:
        outputs = {
            ("git", "diff", "--name-only", "base...HEAD"): "committed.py\n",
            ("git", "diff", "--cached", "--name-only"): "staged.py\n",
            ("git", "diff", "--name-only"): "unstaged.py\n",
            ("git", "ls-files", "--others", "--exclude-standard"): "untracked.py\n",
        }

        def runner(command: list[str]) -> str:
            return outputs[tuple(command)]

        self.assertEqual(
            impact.collect_changed_paths("base", runner=runner),
            ["committed.py", "staged.py", "unstaged.py", "untracked.py"],
        )

    def test_result_has_stable_change_fingerprint(self) -> None:
        first = impact.classify("perfetto-skills", ["src/b.sql", "src/a.sql"])
        second = impact.classify("perfetto-skills", ["src/a.sql", "src/b.sql"])
        self.assertEqual(first["change_fingerprint"], second["change_fingerprint"])
        self.assertRegex(str(first["change_fingerprint"]), r"^[0-9a-f]{64}$")


if __name__ == "__main__":
    unittest.main()
