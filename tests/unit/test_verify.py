import unittest
from pathlib import Path
import tempfile

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

    def test_smartperfetto_environment_uses_repo_pinned_prebuilt(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            traces = source / "test-traces"
            traces.mkdir()
            binary = (
                source
                / "backend"
                / "prebuilts"
                / "trace_processor"
                / "darwin-arm64"
                / "trace_processor_shell"
            )
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            environment = verify.smartperfetto_environment(
                source, system="Darwin", machine="arm64", base={}
            )
            self.assertEqual(
                environment["SMARTPERFETTO_TEST_TRACES"], str(traces.resolve())
            )
            self.assertEqual(
                environment["PERFETTO_TRACE_PROCESSOR"], str(binary.resolve())
            )


if __name__ == "__main__":
    unittest.main()
