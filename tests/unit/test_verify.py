import unittest
from pathlib import Path
import os
import tempfile

from tools import verify


class VerifyCommandTest(unittest.TestCase):
    def test_processor_identity_requires_tag_commit_and_rpc(self) -> None:
        lock = {"tag": "v57.2", "commit": "a" * 40, "rpc_api_version": 14}
        verify.validate_processor_identity(
            f"Perfetto v57.2-aaaaaaaaa ({'a' * 40})\n"
            "Trace Processor RPC API version: 14\n",
            lock,
        )
        with self.assertRaises(ValueError):
            verify.validate_processor_identity(
                f"Perfetto v57.2-aaaaaaaaa ({'a' * 40})\n"
                "Trace Processor RPC API version: 13\n",
                lock,
            )

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
        self.assertFalse(
            any("--smartperfetto" in command for command in commands)
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

    def test_fixture_environment_uses_owned_fixture_root(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixtures = Path(temporary)
            processor = fixtures / "trace_processor_shell"
            processor.write_bytes(b"binary")
            processor.chmod(0o755)
            environment = verify.verification_environment(
                fixtures,
                processor,
                tier="full",
                base={"PATH": os.environ.get("PATH", "")},
            )
            self.assertEqual(
                environment["PERFETTO_FIXTURE_ROOT"], str(fixtures.resolve())
            )
            self.assertEqual(
                environment["PERFETTO_TRACE_PROCESSOR"], str(processor.resolve())
            )
            self.assertEqual(environment["PERFETTO_FIXTURE_TIER"], "full")
            self.assertNotIn("SMARTPERFETTO_SOURCE", environment)


if __name__ == "__main__":
    unittest.main()
