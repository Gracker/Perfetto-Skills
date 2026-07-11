import unittest
from pathlib import Path

from tools import verify


class VerifyCommandTest(unittest.TestCase):
    def test_build_commands_includes_standard_validation(self) -> None:
        self.assertTrue(hasattr(verify, "build_commands"), "build_commands")
        commands = verify.build_commands()
        self.assertIn(
            [
                "agentskills",
                "validate",
                "skills/perfetto-performance-analysis",
            ],
            commands,
        )

    def test_build_commands_adds_catalog_checks_for_smartperfetto(self) -> None:
        source = Path("/tmp/SmartPerfetto")
        commands = verify.build_commands(source)
        self.assertIn(
            [
                verify.sys.executable,
                "tools/export_from_smartperfetto.py",
                "--source",
                str(source),
                "--check",
            ],
            commands,
        )
        self.assertIn(
            [
                verify.sys.executable,
                "tools/validate_catalog.py",
                "--catalog",
                "catalog/smartperfetto-export.json",
                "--skill-root",
                "skills/perfetto-performance-analysis",
            ],
            commands,
        )


if __name__ == "__main__":
    unittest.main()
