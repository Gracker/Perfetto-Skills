from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


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
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_license_is_agpl(self) -> None:
        license_path = ROOT / "LICENSE"
        self.assertTrue(license_path.is_file(), "LICENSE")
        license_text = license_path.read_text(encoding="utf-8")
        self.assertIn("GNU AFFERO GENERAL PUBLIC LICENSE", license_text)


if __name__ == "__main__":
    unittest.main()
