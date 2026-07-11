import unittest

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


if __name__ == "__main__":
    unittest.main()
