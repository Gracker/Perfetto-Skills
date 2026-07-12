import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
from contextlib import redirect_stdout
import io

from tests.support import load_skill_script


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
sys.path.insert(0, str(SKILL / "scripts"))


class RuntimeCliV02Test(unittest.TestCase):
    def test_skill_cli_lists_executable_and_knowledge_only_contracts(self) -> None:
        cli = load_skill_script("perfetto_skill")
        output = io.StringIO()
        with redirect_stdout(output):
            exit_code = cli.main(["list", "--format", "json"])
        self.assertEqual(exit_code, 0)
        result = json.loads(output.getvalue())
        self.assertEqual(result["summary"]["skills"], 230)
        self.assertEqual(result["summary"]["executable"], 198)
        self.assertEqual(result["summary"]["knowledge_only"], 32)

    def test_manifest_query_loads_modules_fragments_and_validation(self) -> None:
        query_cli = load_skill_script("perfetto_query")
        entry = query_cli.load_query_entry(
            "startup_slow_reasons/startup_overview", SKILL
        )
        self.assertEqual(entry["id"], "startup_slow_reasons/startup_overview")
        self.assertIn("android.startup.startups", entry["sql_dependencies"]["declared_modules"])
        self.assertTrue(entry["validation"]["semantic_verified"])
        sql = query_cli.prepare_manifest_query(entry, SKILL)
        self.assertIn("INCLUDE PERFETTO MODULE android.startup.startups;", sql)
        self.assertIn("SELECT", sql)

    def test_probe_separates_schema_from_observed_rows(self) -> None:
        probe = load_skill_script("perfetto_probe")
        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace.pftrace"
            trace.write_bytes(b"trace")
            rows = [
                {"section": "trace_bounds", "key": "start_ns", "value": 1, "encoding": "plain"},
                {"section": "trace_bounds", "key": "end_ns", "value": 2, "encoding": "plain"},
                {"section": "table", "key": "slice", "value": "table", "encoding": "plain"},
                {"section": "table", "key": "gpu_slice", "value": "table", "encoding": "plain"},
                {"section": "table", "key": "gpu_track", "value": "table", "encoding": "plain"},
            ]
            result = probe.build_probe(
                trace,
                rows,
                row_counts={"slice": 12, "gpu_slice": 0, "gpu_track": 0},
                recording_config='data_sources { config { name: "linux.ftrace" } }',
            )
        self.assertEqual(result["capabilities"]["slices"]["state"], "recorded_populated")
        self.assertEqual(result["capabilities"]["gpu"]["state"], "not_recorded")
        self.assertFalse(result["capabilities"]["gpu"]["usable_evidence"])

    def test_probe_classifier_can_emit_all_five_capability_states(self) -> None:
        probe = load_skill_script("perfetto_probe")
        required = probe.CAPABILITY_TABLES["gpu"]
        tables = [
            {"section": "table", "key": table, "value": "table", "encoding": "plain"}
            for table in sorted(required)
        ]
        with tempfile.TemporaryDirectory() as temporary:
            trace = Path(temporary) / "trace.pftrace"
            trace.write_bytes(b"trace")
            cases = {
                "unsupported": probe.build_probe(trace, [], row_counts={}),
                "not_recorded": probe.build_probe(
                    trace, tables, row_counts={table: 0 for table in required}, recording_config="linux.ftrace"
                ),
                "recorded_empty": probe.build_probe(
                    trace, tables, row_counts={table: 0 for table in required}, recording_config="gpu.renderstages"
                ),
                "recorded_populated": probe.build_probe(
                    trace, tables, row_counts={next(iter(required)): 1}, recording_config="gpu.renderstages"
                ),
                "unknown": probe.build_probe(trace, tables, row_counts={table: 0 for table in required}),
            }
        self.assertEqual(
            {name: result["capabilities"]["gpu"]["state"] for name, result in cases.items()},
            {name: name for name in cases},
        )

    def test_binary_identity_requires_hash_commit_and_rpc(self) -> None:
        doctor = load_skill_script("perfetto_doctor")
        lock = {
            "release": {"commit": "abc123", "rpc_api_version": 14},
            "runtime_substrate": {"platforms": {"test": {"sha256": "deadbeef"}}},
        }
        ok = doctor.verify_binary_identity(
            version_text="Perfetto v57.1 (abc123) RPC API: 14",
            binary_sha256="deadbeef",
            platform_key="test",
            source_lock=lock,
        )
        self.assertEqual(ok["status"], "verified")
        mismatch = doctor.verify_binary_identity(
            version_text="Perfetto v57.1 (other) RPC API: 14",
            binary_sha256="deadbeef",
            platform_key="test",
            source_lock=lock,
        )
        self.assertEqual(mismatch["status"], "unsupported")

    def test_locked_processor_rejects_mismatch_unless_explicitly_overridden(self) -> None:
        doctor = load_skill_script("perfetto_doctor")
        mismatch = {
            "status": "unsupported",
            "issues": ["binary SHA-256 does not match the release lock"],
        }
        with self.assertRaisesRegex(RuntimeError, "SHA-256"):
            doctor.require_verified_identity(mismatch, allow_unsupported=False)
        self.assertIs(doctor.require_verified_identity(mismatch, allow_unsupported=True), mismatch)

    def test_report_validator_checks_actual_evidence_cell_and_claim_class(self) -> None:
        from runtime.report import validate_report_payload

        evidence = [
            {
                "evidence_id": "ev_1",
                "trace": {"sha256": "a" * 64, "side": "candidate"},
                "status": "observed",
                "validation": {"semantic_verified": True},
                "processor": {"status": "verified", "binary_sha256": "b" * 64},
                "rows": [{"duration_ms": 42}],
                "identity": {"status": "resolved", "upid": 7},
            }
        ]
        report = {
            "schema_version": 2,
            "trace": [{"side": "candidate", "sha256": "a" * 64}],
            "findings": [
                {
                    "claim": "Startup is slow",
                    "claim_class": "observation",
                    "evidence": [
                        {
                            "evidence_id": "ev_1",
                            "row": 0,
                            "column": "duration_ms",
                            "expected": 42,
                        }
                    ],
                    "alternatives": [],
                    "limitations": [],
                }
            ],
            "evidence": evidence,
            "limitations": [],
        }
        self.assertEqual(validate_report_payload(report), [])
        report["findings"][0]["evidence"][0]["expected"] = 41
        self.assertIn("expected value", " ".join(validate_report_payload(report)))

        report["findings"][0]["evidence"][0]["expected"] = 42
        report["findings"][0]["claim_class"] = "root_cause"
        report["findings"][0]["mechanism"] = "A measured blocking interval delayed display."
        report["findings"][0]["falsifier"] = "No blocking interval overlaps startup."
        evidence[0]["processor"]["status"] = "unsupported"
        self.assertIn("verified processor", " ".join(validate_report_payload(report)))

    def test_report_validator_enforces_schema_trace_binding_and_observed_causal_evidence(self) -> None:
        from runtime.report import validate_report_payload

        report = {
            "schema_version": 2,
            "trace": [{"side": "candidate", "sha256": "a" * 64}],
            "findings": [{
                "claim": "Measured work caused the delay",
                "claim_class": "causal",
                "mechanism": "The measured interval overlaps the startup boundary.",
                "falsifier": "The interval does not overlap startup.",
                "alternatives": [],
                "limitations": [],
                "evidence": [{"evidence_id": "ev_1", "row": 0, "column": "duration_ms", "expected": 42}],
            }],
            "evidence": [{
                "evidence_id": "ev_1",
                "trace": {"sha256": "c" * 64, "side": "baseline"},
                "status": "empty",
                "validation": {"semantic_verified": True},
                "processor": {"status": "verified", "binary_sha256": "b" * 64},
                "rows": [{"duration_ms": 42}],
                "identity": {"status": "resolved", "upid": 7},
            }],
            "limitations": [],
        }
        issues = " ".join(validate_report_payload(report))
        self.assertIn("not declared by report trace", issues)
        self.assertIn("observed evidence", issues)

        del report["trace"]
        self.assertIn("required property trace", " ".join(validate_report_payload(report)))

    def test_query_gate_requires_matching_probe_for_capability_gated_queries(self) -> None:
        from runtime.validation import validate_query_execution

        entry = {
            "id": "example/query",
            "validation": {"default_execution": "capability_gate_required"},
            "sql_dependencies": {"required_tables": ["slice"]},
        }
        with self.assertRaisesRegex(RuntimeError, "probe"):
            validate_query_execution(entry, None, trace_sha256="a" * 64, allow_unverified=False)
        with self.assertRaisesRegex(RuntimeError, "does not match"):
            validate_query_execution(
                entry,
                {"trace": {"sha256": "b" * 64}, "tables": ["slice"]},
                trace_sha256="a" * 64,
                allow_unverified=False,
            )
        gate = validate_query_execution(
            entry,
            {"trace": {"sha256": "a" * 64}, "tables": ["slice"]},
            trace_sha256="a" * 64,
            allow_unverified=False,
        )
        self.assertEqual(gate["status"], "capability_satisfied")

        gpu_entry = {
            **entry,
            "compatibility": {"probe_capabilities": ["gpu"]},
            "sql_dependencies": {"required_tables": []},
        }
        with self.assertRaisesRegex(RuntimeError, "gpu=not_recorded"):
            validate_query_execution(
                gpu_entry,
                {
                    "trace": {"sha256": "a" * 64},
                    "tables": [],
                    "capabilities": {"gpu": {"state": "not_recorded"}},
                },
                trace_sha256="a" * 64,
                allow_unverified=False,
            )

    def test_manifest_schema_checks_declared_modules_even_without_required_tables(self) -> None:
        query_cli = load_skill_script("perfetto_query")
        entry = {
            "sql_dependencies": {
                "declared_modules": ["definitely.missing.module"],
                "required_tables": [],
            }
        }
        with mock.patch.object(
            query_cli, "run_query", side_effect=RuntimeError("unknown module")
        ) as run_query:
            with self.assertRaisesRegex(RuntimeError, "unknown module"):
                query_cli.verify_manifest_schema(
                    entry,
                    Path("missing.trace"),
                    trace_processor="missing-processor",
                    timeout=1,
                    max_output_bytes=1024,
                )
        run_query.assert_called_once()

    def test_report_validator_rejects_non_object_json(self) -> None:
        from runtime.report import validate_report_payload

        self.assertIn("report must be object", " ".join(validate_report_payload([])))


if __name__ == "__main__":
    unittest.main()
