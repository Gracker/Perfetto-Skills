"""Public query contracts for framework process-state and JobScheduler evidence.

Expected values come from the event timeline authored in
``tests/framework_event_traces.py``; offsets below are milliseconds from BASE_NS.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tests import framework_event_traces as traces
from tests.support import SCRIPTS, run_command, trace_processor


RESIDENCY = "android_process_state_residency"
JOBS = "android_job_scheduler_events"
APP = traces.APP.name
SYNC = traces.SYNC.name
JOB_PACKAGE = traces.JOB_APP.name
JOB_WINDOW = {"start_ts": traces.at_ms(10), "end_ts": traces.at_ms(810)}
UNBOUNDED_STATE = {"upid": None, "start_ts": None, "end_ts": None}
QUOTA = "PENDING_JOB_REASON_QUOTA"
CHARGING = "PENDING_JOB_REASON_CONSTRAINT_CHARGING"


def _param_args(params: dict[str, object]) -> list[str]:
    return [item for name, value in sorted(params.items()) for item in ("--param", f"{name}={json.dumps(value)}")]


@unittest.skipUnless(os.environ.get("PERFETTO_TRACE_PROCESSOR"), "trace processor is not configured")
class _FrameworkTraceCase(unittest.TestCase):
    temporary: tempfile.TemporaryDirectory[str]
    state_trace: Path
    job_trace: Path

    @classmethod
    def setUpClass(cls) -> None:
        cls.temporary = tempfile.TemporaryDirectory()
        root = Path(cls.temporary.name)
        cls.state_trace = traces.write_process_state_trace(root / "process-state.pb")
        cls.job_trace = traces.write_job_scheduler_trace(root / "job-scheduler.pb")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def invoke_query(self, trace: Path, query_id: str, **params: object) -> tuple[subprocess.CompletedProcess[str], Path]:
        output = Path(self.temporary.name) / f"{self.id()}.json"
        command = [
            sys.executable,
            str(SCRIPTS / "perfetto_query.py"),
            str(trace),
            "--query-id",
            query_id,
            "--trace-processor",
            trace_processor(),
            "--output",
            str(output),
            *_param_args(params),
        ]
        return run_command(command), output

    def rows(self, trace: Path, query_id: str, **params: object) -> list[dict[str, object]]:
        completed, output = self.invoke_query(trace, query_id, **params)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        return json.loads(output.read_text(encoding="utf-8"))

    def run_skill(self, trace: Path, skill: str, **params: object) -> dict[str, object]:
        with tempfile.TemporaryDirectory() as temporary:
            run_command(
                [
                    sys.executable,
                    str(SCRIPTS / "perfetto_skill.py"),
                    "run",
                    str(trace),
                    "--skill",
                    skill,
                    "--trace-processor",
                    trace_processor(),
                    "--output-dir",
                    temporary,
                    *_param_args(params),
                ]
            )
            return json.loads((Path(temporary) / "result.json").read_text(encoding="utf-8"))

    def assert_named_scope_runs_and_exact_upid_is_refused(self, trace: Path, skill: str, **scope: object) -> None:
        self.assertEqual(self.run_skill(trace, skill, **scope)["status"], "completed")
        blocked = self.run_skill(trace, skill, upid=2)
        self.assertEqual(blocked["status"], "identity_blocked")
        self.assertIn("Exact UPID scope is unsupported", blocked["error"])


class ProcessStateEvidenceTest(_FrameworkTraceCase):
    def state_rows(self, step: str, **params: object) -> list[dict[str, object]]:
        return self.rows(self.state_trace, f"{RESIDENCY}/{step}", **params)

    def residency(self, process_name: str, **window: object) -> dict[tuple[object, object], tuple[object, object]]:
        rows = self.state_rows("process_state_residency", process_name=process_name, **{**UNBOUNDED_STATE, **window})
        return {(row["process_name"], row["state"]): (row["residency_ms"], row["residency_pct"]) for row in rows}

    def transitions(self, **window: object) -> list[dict[str, object]]:
        return self.state_rows("process_state_transitions", process_name=APP, **{**UNBOUNDED_STATE, **window})

    def test_runtime_reports_the_v59_lifecycle_columns(self) -> None:
        self.assertEqual(self.state_rows("process_state_capability")[0]["status"], "runtime_supported")

    def test_alive_residency_excludes_lifecycle_markers(self) -> None:
        # TOP 60-160, LAST_ACTIVITY 160-460, CACHED_ACTIVITY 460-760 (binder death);
        # NONEXISTENT 20-60 and EXITED after 760 are not alive time.
        residency = self.residency(APP)
        self.assertEqual(
            {state: value for (name, state), value in residency.items() if name == APP},
            {"TOP": (100.0, 14.29), "LAST_ACTIVITY": (300.0, 42.86), "CACHED_ACTIVITY": (300.0, 42.86)},
        )

    def test_open_state_runs_to_trace_end_as_alive_time(self) -> None:
        # The last event is at 820 and :sync entered CACHED_EMPTY at 520.
        self.assertEqual(self.residency(SYNC)[(SYNC, "CACHED_EMPTY")], (300.0, 37.5))

    def test_state_change_reason_keeps_the_public_reason_column(self) -> None:
        row = next(row for row in self.transitions() if row["state"] == "LAST_ACTIVITY")
        self.assertEqual(
            (row["prev_state"], row["prev_state_ms"], row["reason"], row["lifecycle"]),
            ("TOP", 100.0, "OOM_ADJ_REASON_ACTIVITY", "state_change"),
        )
        self.assertNotIn("state_change_reason", row)

    def test_start_metadata_keeps_zero_distinct_from_missing(self) -> None:
        rows = self.transitions()
        start = next(row for row in rows if row["lifecycle"] == "process_start_pending")
        self.assertEqual(
            (start["process_name"], start["hosting_type"], start["trigger_type"]),
            (APP, "HOSTING_TYPE_ACTIVITY", "TRIGGER_TYPE_JOB"),
        )
        self.assertEqual((start["bind_application_delay_ms"], start["process_start_delay_ms"]), (0, 40))
        without_metadata = next(row for row in rows if row["process_name"] == SYNC and row["state"] == "CACHED_EMPTY")
        for column in ("hosting_type", "bind_application_delay_ms", "process_start_delay_ms", "exit_reason"):
            self.assertIsNone(without_metadata[column], column)

    def test_exit_reason_is_separate_from_the_state_change_reason(self) -> None:
        row = next(row for row in self.transitions() if row["lifecycle"] == "process_exited")
        self.assertEqual(
            (row["prev_state"], row["state"], row["prev_state_ms"], row["reason"]),
            ("CACHED_ACTIVITY", "EXITED", 300.0, None),
        )
        self.assertEqual(
            (row["exit_reason"], row["exit_subreason"]),
            ("APP_EXIT_REASON_LOW_MEMORY", "APP_EXIT_SUBREASON_MEMORY_PRESSURE"),
        )

    def test_last_observed_state_separates_ended_from_alive(self) -> None:
        rows = self.state_rows("process_state_last_observed", process_name=APP, upid=None, end_ts=None)
        by_name = {row["process_name"]: row for row in rows}
        self.assertEqual(
            (by_name[APP]["last_state"], by_name[APP]["lifecycle"], by_name[APP]["process_end_ts"]),
            ("CACHED_ACTIVITY", "process_ended", traces.at_ms(760)),
        )
        self.assertEqual(
            (by_name[SYNC]["last_state"], by_name[SYNC]["lifecycle"], by_name[SYNC]["process_end_ts"]),
            ("CACHED_EMPTY", "alive_at_trace_end", None),
        )

    def test_last_observed_honors_the_end_of_the_window(self) -> None:
        rows = self.state_rows("process_state_last_observed", process_name=APP, upid=None, end_ts=traces.at_ms(300))
        self.assertEqual(next(row for row in rows if row["process_name"] == APP)["last_state"], "LAST_ACTIVITY")

    def test_window_clips_residency_and_drops_outside_lifecycle(self) -> None:
        # Window 310-560: LAST_ACTIVITY 310-460 and CACHED_ACTIVITY 460-560.
        window = {"start_ts": traces.at_ms(310), "end_ts": traces.at_ms(560)}
        residency = self.residency(APP, **window)
        self.assertEqual(residency[(APP, "LAST_ACTIVITY")], (150.0, 60.0))
        self.assertEqual(residency[(APP, "CACHED_ACTIVITY")], (100.0, 40.0))
        self.assertNotIn((APP, "TOP"), residency)
        rows = self.transitions(**window)
        self.assertEqual({row["lifecycle"] for row in rows}, {"state_change"})
        self.assertEqual([row["state"] for row in rows if row["process_name"] == APP], ["CACHED_ACTIVITY"])

    def test_package_name_scopes_the_family_and_excludes_other_processes(self) -> None:
        names = {name for name, _ in self.residency(APP)}
        self.assertEqual(names, {APP, SYNC})
        self.assertEqual({name for name, _ in self.residency(SYNC)}, {SYNC})

    def test_missing_state_data_is_reported_rather_than_zero(self) -> None:
        stateless = self.state_rows("process_state_data", process_name=traces.STATELESS.name, upid=None)[0]
        self.assertEqual(
            (stateless["matched_process_count"], stateless["status"]),
            (0, "no_process_state_for_requested_process"),
        )
        self.assertEqual(self.residency(traces.STATELESS.name), {})
        absent_events = self.rows(self.job_trace, f"{RESIDENCY}/process_state_data", process_name=JOB_PACKAGE, upid=None)[0]
        self.assertEqual((absent_events["state_event_count"], absent_events["status"]), (0, "no_process_state_data"))

    def test_an_unknown_process_is_refused_by_the_identity_gate(self) -> None:
        completed, _ = self.invoke_query(
            self.state_trace, f"{RESIDENCY}/process_state_data", process_name="com.example.absent", upid=None
        )
        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("Process identity could not be verified", completed.stderr)

    def test_skill_completes_by_name_and_refuses_exact_upid(self) -> None:
        self.assert_named_scope_runs_and_exact_upid_is_refused(self.state_trace, RESIDENCY, process_name=APP)



class JobSchedulerEvidenceTest(_FrameworkTraceCase):
    def job_rows(self, step: str, package: str = JOB_PACKAGE, **window: object) -> list[dict[str, object]]:
        bounds = window or JOB_WINDOW
        return self.rows(self.job_trace, f"{JOBS}/{step}", package=package, **bounds)

    def summary(self, package: str = JOB_PACKAGE, **window: object) -> dict[object, dict[str, object]]:
        return {row["pending_reason"]: row for row in self.job_rows("pending_reason_summary", package, **window)}

    def test_runtime_reports_pending_reason_support(self) -> None:
        rows = self.rows(self.job_trace, f"{JOBS}/pending_reason_capability")
        self.assertEqual(rows[0]["status"], "runtime_supported")

    def test_atrace_job_execution_is_attributed_to_package_and_uid(self) -> None:
        self.assertEqual(
            self.job_rows("job_events"),
            [{
                "dur_ms": 30.0,
                "job_name": ".SyntheticJob",
                "package_name": JOB_PACKAGE,
                "ts": traces.at_ms(150),
                "uid": traces.JOB_APP.uid,
            }],
        )

    def test_job_execution_window_uses_overlap(self) -> None:
        overlapping = {"start_ts": traces.at_ms(170), "end_ts": traces.at_ms(175)}
        after = {"start_ts": traces.at_ms(190), "end_ts": traces.at_ms(195)}
        self.assertEqual(len(self.job_rows("job_events", **overlapping)), 1)
        self.assertEqual(self.job_rows("job_events", **after), [])

    def test_known_wait_durations_stay_reported_milliseconds(self) -> None:
        # 1500 + 500 exceeds the 800 ms window: reported waits are never clipped.
        row = self.summary()[CHARGING]
        self.assertEqual(
            (row["completed_job_count"], row["known_duration_count"], row["missing_duration_count"], row["reported_wait_ms"]),
            (2, 2, 0, 2000),
        )

    def test_missing_wait_duration_stays_null(self) -> None:
        row = self.summary()[QUOTA]
        self.assertEqual(
            (row["completed_job_count"], row["known_duration_count"], row["missing_duration_count"]),
            (1, 0, 1),
        )
        self.assertIsNone(row["reported_wait_ms"])

    def test_only_completed_jobs_contribute_reasons(self) -> None:
        # Job 103 was cancelled and job 104 never finished.
        self.assertEqual(set(self.summary()), {CHARGING, QUOTA})
        self.assertEqual(
            self.job_rows("pending_reason_data")[0],
            {"completed_job_count": 2, "missing_duration_count": 1, "reason_entry_count": 3, "status": "available"},
        )

    def test_window_selects_jobs_by_completed_slice_start(self) -> None:
        unbounded = self.summary(start_ts=None, end_ts=None)[QUOTA]
        self.assertEqual(
            (unbounded["completed_job_count"], unbounded["known_duration_count"], unbounded["missing_duration_count"], unbounded["reported_wait_ms"]),
            (2, 1, 1, 9999),
        )

    def test_attribution_is_by_package_and_uid_without_peer_jobs(self) -> None:
        self.assertEqual({row["uid"] for row in self.summary().values()}, {traces.JOB_APP.uid})
        peer = self.summary(traces.JOB_PEER.name)[CHARGING]
        self.assertEqual(
            (peer["package_name"], peer["uid"], peer["reported_wait_ms"]),
            (traces.JOB_PEER.name, traces.JOB_PEER.uid, 9000),
        )

    def test_overlapping_reasons_are_not_summed_into_a_queue_latency(self) -> None:
        self.assertEqual(
            set(self.summary()[CHARGING]),
            {"package_name", "uid", "pending_reason", "completed_job_count", "known_duration_count", "missing_duration_count", "reported_wait_ms"},
        )

    def test_no_completed_jobs_is_a_status_rather_than_a_zero_wait(self) -> None:
        idle = traces.JOB_IDLE.name
        self.assertEqual(
            self.job_rows("pending_reason_data", idle)[0],
            {"completed_job_count": 0, "missing_duration_count": 0, "reason_entry_count": 0, "status": "no_completed_jobs_with_pending_reasons"},
        )
        self.assertEqual(self.job_rows("pending_reason_summary", idle), [])

    def test_skill_completes_by_package_and_refuses_exact_upid(self) -> None:
        self.assert_named_scope_runs_and_exact_upid_is_refused(self.job_trace, JOBS, package=JOB_PACKAGE)
