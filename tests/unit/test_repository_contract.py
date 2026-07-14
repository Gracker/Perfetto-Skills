from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
PROJECT_LINKS = {
    "https://github.com/Gracker/SmartPerfetto",
    "https://github.com/Gracker/Perfetto-Skills",
    "https://github.com/google/perfetto/tree/main/ai/skills/perfetto",
    "https://perfetto.dev/docs/getting-started/using-ai",
}


class RepositoryContractTest(unittest.TestCase):
    def test_required_public_files_exist(self) -> None:
        for relative in (
            "README.md",
            "LICENSE",
            "NOTICE",
            "SECURITY.md",
            "CONTRIBUTING.md",
            "AGENTS.md",
            "pyproject.toml",
            "docs/architecture.md",
            "docs/compatibility.md",
            "docs/migration-coverage.md",
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_license_is_agpl(self) -> None:
        license_path = ROOT / "LICENSE"
        self.assertTrue(license_path.is_file(), "LICENSE")
        license_text = license_path.read_text(encoding="utf-8")
        self.assertIn("GNU AFFERO GENERAL PUBLIC LICENSE", license_text)

    def test_readmes_offer_three_perfetto_project_choices(self) -> None:
        for name in ("README.md", "README.zh-CN.md"):
            with self.subTest(readme=name):
                text = (ROOT / name).read_text(encoding="utf-8")
                self.assertIn("SmartPerfetto", text)
                self.assertIn("Perfetto Skills", text)
                self.assertIn("Google", text)
                for link in PROJECT_LINKS:
                    self.assertIn(link, text)

    def test_agent_guide_routes_cross_repository_review(self) -> None:
        text = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("tools/check_cross_repo_impact.py", text)
        self.assertIn("docs/maintenance/upstream-sync.md", text)
        for decision in ("required", "not_required", "deferred"):
            self.assertIn(decision, text)

    def test_normal_evals_do_not_depend_on_sibling_smartperfetto(self) -> None:
        text = (ROOT / "evals/evals.json").read_text(encoding="utf-8")
        self.assertNotIn("../SmartPerfetto", text)
        self.assertIn("PERFETTO_FIXTURE_ROOT", text)


if __name__ == "__main__":
    unittest.main()
