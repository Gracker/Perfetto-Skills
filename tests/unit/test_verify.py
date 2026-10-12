import unittest
from pathlib import Path
import os
import tempfile
import io
import json
from contextlib import redirect_stdout
from unittest import mock

from tools import verify
from tools.run_selected_tests import run_selected_tests


class VerifyCommandTest(unittest.TestCase):
    def test_unit_tier_needs_no_trace_preparation(self) -> None:
        output = io.StringIO()
        with mock.patch.object(verify, "resolve_trace_processor") as processor, mock.patch.object(
            verify, "resolve_fixture_root"
        ) as fixtures, mock.patch.object(verify, "run") as run, mock.patch.dict(
            os.environ, {"PERFETTO_TRACE_PROCESSOR": "/stale/binary", "PERFETTO_FIXTURE_ROOT": "/stale/traces"}
        ), redirect_stdout(output):
            self.assertEqual(verify.main(["--tier", "unit"]), 0)
        processor.assert_not_called()
        fixtures.assert_not_called()
        commands = [call.args[0] for call in run.call_args_list]
        self.assertIn(
            [verify.sys.executable, "-m", "unittest", "discover", "-s", "tests/unit", "-t", ".", "-p", "test_*.py"],
            commands,
        )
        summary = json.loads(output.getvalue())
        self.assertFalse(summary["complete_gate"])
        self.assertIsNone(summary["trace_processor"])
        for call in run.call_args_list:
            self.assertNotIn("PERFETTO_TRACE_PROCESSOR", call.kwargs["env"])
            self.assertNotIn("PERFETTO_FIXTURE_ROOT", call.kwargs["env"])

    def test_default_gate_keeps_complete_test_discovery(self) -> None:
        self.assertEqual(
            verify.build_commands()[3],
            [verify.sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"],
        )

    def test_failed_static_check_does_not_prepare_real_traces(self) -> None:
        with mock.patch.object(verify, "resolve_trace_processor") as processor, mock.patch.object(
            verify, "resolve_fixture_root"
        ) as fixtures, mock.patch.object(verify, "run", side_effect=SystemExit(1)):
            with self.assertRaises(SystemExit):
                verify.main([])
        processor.assert_not_called()
        fixtures.assert_not_called()

    def test_selected_unit_target_skips_trace_preparation_at_default_tier(self) -> None:
        with mock.patch.object(verify, "resolve_trace_processor") as processor, mock.patch.object(
            verify, "resolve_fixture_root"
        ) as fixtures, mock.patch.object(verify, "run"), redirect_stdout(io.StringIO()):
            self.assertEqual(verify.main(["--test", "tests.unit.test_verify"]), 0)
        processor.assert_not_called()
        fixtures.assert_not_called()

    def test_selected_integration_target_prepares_verified_owned_traces(self) -> None:
        with mock.patch.object(verify, "resolve_trace_processor", return_value=Path("/processor")) as processor, mock.patch.object(
            verify, "resolve_fixture_root", return_value=Path("/fixtures")
        ) as fixtures, mock.patch.object(verify, "verification_environment", return_value={}) as environment, mock.patch.object(
            verify, "run"
        ), redirect_stdout(io.StringIO()):
            self.assertEqual(verify.main(["--test", "tests.integration.test_fixture_manifest"]), 0)
        processor.assert_called_once()
        fixtures.assert_called_once()
        environment.assert_called_once_with(Path("/fixtures"), Path("/processor"), tier="full")

    def test_focused_targets_are_explicit_and_do_not_discover_all(self) -> None:
        commands = verify.build_commands(tier="unit", tests=["tests.unit.test_verify"])
        self.assertIn([verify.sys.executable, "tools/run_selected_tests.py", "tests.unit.test_verify"], commands)
        self.assertFalse(any("discover" in command for command in commands))

    def test_static_tier_has_no_test_process(self) -> None:
        commands = verify.build_commands(tier="static")
        self.assertFalse(any("unittest" in command for command in commands))
        self.assertIn([verify.sys.executable, "tools/validate_all_queries.py"], commands)

    def test_empty_or_unknown_test_selection_fails(self) -> None:
        self.assertEqual(run_selected_tests([]), 2)
        self.assertEqual(run_selected_tests(["tests.unit.test_missing"]), 2)

    def test_focused_test_failures_are_not_a_pass(self) -> None:
        with mock.patch("tools.run_selected_tests.unittest.TestLoader") as loader, mock.patch(
            "tools.run_selected_tests.unittest.TextTestRunner"
        ) as runner:
            loader.return_value.errors = []
            loader.return_value.loadTestsFromNames.return_value.countTestCases.return_value = 1
            runner.return_value.run.return_value.wasSuccessful.return_value = False
            self.assertEqual(run_selected_tests(["tests.unit.test_verify"]), 1)

    def test_invalid_tier_options_fail_before_preparation(self) -> None:
        for args in (
            ["--tier", "static", "--test", "tests.unit.test_verify"],
            ["--tier", "unit", "--test", "tests.integration.test_real_trace"],
            ["--tier", "unit", "--offline"],
            ["--test", "not_a_repository_test"],
        ):
            with self.subTest(args=args), mock.patch.object(verify, "resolve_trace_processor") as processor:
                with self.assertRaises(SystemExit) as error:
                    verify.main(args)
                self.assertEqual(error.exception.code, 2)
                processor.assert_not_called()

    def test_processor_identity_requires_tag_commit_and_rpc(self) -> None:
        lock = {
            "runtime": {
                "reported_version": "v57.2",
                "revision": "a" * 40,
                "rpc_api_version": 14,
            }
        }
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
        with self.assertRaisesRegex(ValueError, "version or commit"):
            verify.validate_processor_identity(
                f"Perfetto v57.2-deadbeef ({'a' * 40})\n"
                "Trace Processor RPC API version: 14\n",
                lock,
            )
        verify.validate_processor_identity(
            f"Perfetto v57.2 ({'a' * 40})\n"
            "Trace Processor RPC API version: 14\n",
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

    def test_owned_semantic_assertions_execute_once_per_gate(self) -> None:
        # FixtureManifestTest (unittest discover) owns their execution.
        commands = verify.build_commands()
        self.assertIn([verify.sys.executable, "tools/validate_all_queries.py"], commands)
        self.assertFalse(any("--execute" in command for command in commands))

    def test_build_commands_adds_catalog_checks_for_smartperfetto(self) -> None:
        source = Path("/tmp/SmartPerfetto")
        commands = verify.build_commands(source)
        self.assertIn(
            [
                verify.sys.executable,
                "tools/sync_smartperfetto.py",
                "--source",
                str(source),
                "--report-dir",
                "test-output/verify-smartperfetto",
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

    def test_fixture_environment_removes_legacy_smartperfetto_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            fixtures = Path(temporary)
            processor = fixtures / "trace_processor_shell"
            processor.write_bytes(b"binary")
            processor.chmod(0o755)
            environment = verify.verification_environment(
                fixtures,
                processor,
                tier="full",
                base={
                    "PATH": os.environ.get("PATH", ""),
                    "SMARTPERFETTO_SOURCE": "/tmp/stale-source",
                },
            )
            self.assertNotIn("SMARTPERFETTO_SOURCE", environment)


if __name__ == "__main__":
    unittest.main()
