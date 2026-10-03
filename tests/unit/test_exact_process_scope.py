"""Exact-UPID process scopes, as SmartPerfetto runs them (processScopeSql.ts,
identityGate.ts and the exact branches of skillExecutor.ts)."""

import copy
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

from tests.support import load_skill_script
from tools import export_from_smartperfetto as exporter


load_skill_script("_common")
identity = load_skill_script("process_identity")

EFFECTIVE = "fragments/effective_target_processes.sql"
EFFECTIVE_SQL = "effective_target_processes AS (SELECT * FROM process WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid})"


def fragments(path):
    return {EFFECTIVE: EFFECTIVE_SQL, "fragments/other.sql": "other AS (SELECT 1)"}.get(path)


class SqlScopeDeclarationTest(unittest.TestCase):
    def error(self, **source):
        return exporter.sql_scope_declaration_error(source, fragments)

    def test_supported_declarations(self) -> None:
        self.assertIsNone(self.error(
            sql="SELECT * FROM effective_target_processes", sql_fragments=[EFFECTIVE],
            process_scope={"role": "target", "binding": "effective_target_processes"},
        ))
        self.assertIsNone(self.error(
            sql="SELECT * FROM process WHERE upid = ${__process_scope.upid}",
            process_scope={"role": "target", "binding": "native_upid"},
        ))
        self.assertIsNone(self.error(sql="SELECT 1", process_scope={"role": "global_context"}))
        self.assertIsNone(self.error(sql="SELECT 1", process_scope={"role": "target", "exact_unavailable": "No UPID"}))

    def test_each_refusal_reason(self) -> None:
        cases = [
            ({"sql": "SELECT 1"}, "SQL has no process_scope declaration"),
            ({"sql": "SELECT 1", "process_scope": {"role": "other"}}, "Unknown process_scope role"),
            ({"sql": "SELECT 1", "process_scope": {"role": "target", "exact_unavailable": " "}},
             "exact_unavailable requires an authored reason"),
            ({"sql": "SELECT 1", "process_scope": {"role": "target", "context_fields": {"target": ["a"]}}},
             "Invalid process_scope context_fields declaration"),
            ({"sql": "SELECT 1", "sql_fragments": ["fragments/missing.sql"], "process_scope": {"role": "global_context"}},
             "Required SQL fragment is missing: fragments/missing.sql"),
            ({"sql": "SELECT 1", "process_scope": {"role": "peer_context", "binding": "native_upid"}},
             "Context evidence cannot claim a target UPID binding"),
            ({"sql": "SELECT '${__process_scope.upid}'", "process_scope": {"role": "target", "binding": "native_upid"}},
             "native_upid SQL must bind the trusted __process_scope.upid"),
            ({"sql": "SELECT * FROM effective_target_processes", "process_scope": {"role": "target", "binding": "effective_target_processes"}},
             "Target SQL must include effective_target_processes.sql"),
            ({"sql": "SELECT * FROM process -- effective_target_processes", "sql_fragments": [EFFECTIVE],
              "process_scope": {"role": "target", "binding": "effective_target_processes"}},
             "Target SQL does not consume effective_target_processes"),
            ({"sql": "SELECT 1", "process_scope": {"role": "target", "binding": "custom"}},
             "Target SQL has no supported exact UPID binding"),
        ]
        for source, reason in cases:
            with self.subTest(reason=reason):
                self.assertEqual(self.error(**source), reason)


def _query(query_id, status, *, variant=None, setups=()):
    record = {"status": status} if status == "supported" else {"status": status, "reason": "SQL has no process_scope declaration"}
    if variant:
        record["exact_query_id"] = variant
    return {"id": query_id, "compatibility": {"exact_scope": record}, "sql_dependencies": {"setup_queries": list(setups)}}


class ExactAdmissionTest(unittest.TestCase):
    def setUp(self) -> None:
        self.queries = {
            "a/root": _query("a/root", "supported"),
            "b/read": _query("b/read", "unsupported"),
            # The record of a query with an exact variant is the variant's; the
            # variant's own setup SQL, not the named query's, is what runs.
            "c/read": _query("c/read", "supported", variant="c/read.exact", setups=["b/read"]),
            "c/read.exact": _query("c/read.exact", "supported"),
            "d/read": _query("d/read", "supported", setups=["b/read"]),
        }
        self.skills = {
            "a": {"id": "a", "type": "atomic", "query_id": "a/root", "process_scope": {"role": "target"}, "steps": []},
            "b": {"id": "b", "type": "composite", "steps": [{"id": "read", "query_id": "b/read"}]},
            "c": {"id": "c", "type": "composite", "steps": [{"id": "read", "query_id": "c/read"}]},
            "d": {"id": "d", "type": "composite", "steps": [{"id": "read", "query_id": "d/read"}]},
            "parent": {"id": "parent", "type": "composite", "steps": [
                {"id": "child", "type": "skill", "skill": "a"},
                {"id": "each", "type": "iterator", "item_skill": "b"},
            ]},
            "loop": {"id": "loop", "type": "composite", "steps": [{"id": "self", "type": "skill", "skill": "loop"}]},
            "piped": {"id": "piped", "type": "composite", "steps": [{"id": "p", "type": "pipeline"}]},
            "empty": {"id": "empty", "type": "composite", "steps": []},
        }

    def support(self, skill_id):
        return identity.exact_scope_support(skill_id, self.skills.get, self.queries.__getitem__)

    def test_closure_reasons_follow_smartperfetto(self) -> None:
        self.assertIsNone(self.support("a"))
        self.assertIsNone(self.support("c"))  # its exact variant is what runs
        self.assertEqual(self.support("b"), "b.read: SQL has no process_scope declaration")
        self.assertEqual(self.support("parent"), "b.read: SQL has no process_scope declaration")
        self.assertEqual(self.support("loop"), "Cyclic Skill dependency: loop")
        self.assertEqual(self.support("piped"), "piped.p: exact UPID execution is not declared for pipeline")
        self.assertEqual(self.support("empty"), "Skill has no executable SQL or steps: empty")
        self.skills["parent"]["steps"][0]["skill"] = "missing"
        self.assertEqual(self.support("parent"), "parent.child: Skill dependency is missing: missing")

    def test_the_selected_variant_record_decides_not_a_stale_base_record(self) -> None:
        self.queries["c/read.exact"] = _query("c/read.exact", "unsupported")
        self.assertEqual(self.support("c"), "c.read: SQL has no process_scope declaration")
        del self.queries["c/read.exact"]
        self.assertEqual(self.support("c"), "c.read: SQL descriptor is missing: c/read.exact")

    def test_setup_sql_assembled_in_front_of_a_query_is_part_of_its_closure(self) -> None:
        self.assertEqual(self.support("d"), "d.read<b/read>: SQL has no process_scope declaration")

    def test_admission_text_names_supported_target_skills(self) -> None:
        error = identity.exact_scope_admission_error("b", self.skills.get, self.queries.__getitem__, lambda: sorted(self.skills))
        self.assertEqual(error, "Exact UPID scope is unsupported: b.read: SQL has no process_scope declaration. Use a supported exact Skill: a.")
        del self.skills["a"]
        error = identity.exact_scope_admission_error("b", self.skills.get, self.queries.__getitem__, lambda: sorted(self.skills))
        self.assertTrue(error.endswith("Use execute_sql with an explicit verified process.upid equality on the target relation."))
        self.assertIsNone(identity.exact_scope_admission_error("c", self.skills.get, self.queries.__getitem__, lambda: []))


def verified(upid=42, pid=4242, name="com.example"):
    return {
        "status": "verified", "requestedName": None, "canonicalPackageName": name,
        "recommendedProcessNameParam": name, "upids": [upid], "confidenceScore": 100, "rawStatus": "confirmed",
        "evidenceSources": ["upid"], "warnings": [],
        "candidates": [{"rank": 1, "confidenceScore": 100, "upid": upid, "pid": pid, "processName": name,
                        "canonicalPackageName": name, "recommendedProcessNameParam": name}],
    }


class ExactGateTest(unittest.TestCase):
    def gate(self, resolve):
        gate = identity.IdentityGate(mock.Mock(), mock.Mock())
        gate.resolve = resolve
        return gate

    def skill(self):
        return {"id": "detail", "identity": {"policy": "verify_if_present", "aliases": ["process_name"]},
                "inputs": [{"name": "upid"}, {"name": "pid"}, {"name": "process_name"}]}

    def test_an_iterator_item_upid_issues_an_exact_scope_and_fills_declared_selectors(self) -> None:
        resolve = mock.Mock(return_value=verified())
        result = self.gate(resolve).apply(self.skill(), {"upid": 42, "pid": 4242, "process_name": "com.example"}, {})
        self.assertTrue(result.allowed, result.error)
        self.assertEqual((result.scope.mode, result.scope.upid), ("exact_upid", 42))
        self.assertEqual(result.params, {"upid": 42, "pid": 4242, "process_name": "com.example"})
        self.assertEqual(result.evidence()["upid"], 42)

    def test_a_child_inherits_the_exact_upid_and_cannot_change_it(self) -> None:
        resolve = mock.Mock(return_value=verified())
        gate = self.gate(resolve)
        parent = gate.apply(self.skill(), {"upid": 42}, {})
        child = gate.apply(self.skill(), {}, {}, parent.scope)
        self.assertTrue(child.allowed, child.error)
        self.assertIs(child.scope, parent.scope)
        self.assertEqual(resolve.call_count, 1)  # the verified identity is reused
        self.assertEqual(child.params["upid"], 42)
        conflict = gate.apply(self.skill(), {"upid": 7}, {}, parent.scope)
        self.assertEqual(conflict.error, "Child Skill cannot change the inherited exact UPID")
        wrong_name = gate.apply(self.skill(), {"process_name": "com.other"}, {}, parent.scope)
        self.assertEqual(wrong_name.error, "Explicit process name/PID conflicts with the selected UPID")

    def test_a_reused_pid_cannot_scope_exactly(self) -> None:
        reused = verified()
        reused["upids"] = [42, 43]
        result = self.gate(lambda _target: reused).apply(self.skill(), {"pid": 4242}, {})
        self.assertIn("Explicit PID must resolve to one verified UPID", result.error)


class ExactBindingTest(unittest.TestCase):
    def setUp(self) -> None:
        self.query = load_skill_script("perfetto_query")

    def test_an_exact_scope_binds_its_upid_and_refuses_another(self) -> None:
        common = self.query.__dict__["bind_runtime_process_scope"].__globals__
        bind, render = common["bind_runtime_process_scope"], common["render_sql_template"]
        scope = bind(
            {"status": "resolved"}, identity_policy={"policy": "verify_if_present", "aliases": []},
            parameters={"upid": 42, "pid": 4242}, supplied_parameters={"upid": 42, "pid": 4242},
            name_parameters=[], trace_sha256="a" * 64, trace_side="trace_a", exact_upid=42,
        )
        sql = render("SELECT ${__process_scope.upid} AS u", {"upid": 42, "pid": 4242}, {},
                     process_scope=scope, trace_sha256="a" * 64, trace_side="trace_a")
        self.assertEqual(sql, "SELECT 42 AS u")
        with self.assertRaisesRegex(ValueError, "selectors changed"):
            bind({"status": "resolved"}, identity_policy={"policy": "verify_if_present", "aliases": []},
                 parameters={"upid": 7}, supplied_parameters={}, name_parameters=[],
                 trace_sha256="a" * 64, trace_side="trace_a", exact_upid=42)
        with self.assertRaisesRegex(ValueError, "verified exact process scope"):
            bind({"status": "resolved", "target": "x"}, identity_policy={"policy": "verify_if_present", "aliases": []},
                 parameters={"upid": 42}, supplied_parameters={"upid": 42}, name_parameters=[],
                 trace_sha256="a" * 64, trace_side="trace_a")

    def test_only_the_issuing_gate_grants_its_exact_upid_to_sql(self) -> None:
        # perfetto_query reads the gate module under its runtime import name.
        self.query.verified_exact_upid(None, None)
        runtime_identity = sys.modules["process_identity"]
        owner = runtime_identity.IdentityGate(mock.Mock(), mock.Mock())
        owner.resolve = lambda _target: verified()
        issued = owner.apply({"id": "s", "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid"}]},
                             {"upid": 42}, {}).scope
        self.assertEqual(self.query.verified_exact_upid(issued, owner), 42)
        forged = runtime_identity.IdentityScope("exact_upid", None, None, owner, 42)
        other_trace = runtime_identity.IdentityGate(mock.Mock(), mock.Mock())
        for scope, gate in ((forged, owner), (issued, other_trace), (issued, None)):
            with self.subTest(scope=scope, gate=gate), self.assertRaisesRegex(ValueError, "untrusted"):
                self.query.verified_exact_upid(scope, gate)
        # The binder applies the same check: a borrowed scope renders nothing.
        query = {"id": "s/root", "step_id": "root", "process_scope": {"role": "target", "binding": "native_upid"},
                 "compatibility": {"exact_scope": {"status": "supported"}},
                 "identity": {"policy": "verify_if_present", "aliases": []},
                 "template": {"runtime_bindings": ["__process_scope.upid"], "name_parameters": []}}
        with self.assertRaisesRegex(ValueError, "untrusted"):
            self.query.bind_manifest_process_scope(
                [(query, "SELECT ${__process_scope.upid}")], {}, {}, identity_result={"status": "resolved"},
                trace=Path("."), trace_sha256="b" * 64, trace_side="trace_b", trace_processor=None,
                timeout=1, max_output_bytes=1, identity_scope=issued, identity_owner=other_trace,
            )

    def test_declared_unavailability_is_decided_for_the_whole_closure_before_trace_work(self) -> None:
        self.query.verified_exact_upid(None, None)
        runtime_identity = sys.modules["process_identity"]
        owner = runtime_identity.IdentityGate(mock.Mock(), mock.Mock())
        owner.resolve = lambda _target: verified()
        scope = owner.apply({"id": "s", "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid"}]},
                            {"upid": 42}, {}).scope
        setup = {"id": "s/setup", "step_id": "setup", "compatibility": {"exact_scope": {"status": "supported"}},
                 "process_scope": {"role": "target", "exact_unavailable": "No UPID relationship", "limitations": ["coarse"]}}
        leaf = {"id": "s/leaf", "step_id": "leaf", "compatibility": {"exact_scope": {"status": "supported"}},
                "process_scope": {"role": "global_context"}}
        with self.assertRaises(self.query.ExactScopeUnavailable) as raised:
            self.query.raise_if_exact_unavailable([(setup, ""), (leaf, "")], scope, trace_sha256="a" * 64, trace_side="trace_a")
        self.assertEqual(raised.exception.code, "exact_scope_unavailable")
        self.assertEqual(raised.exception.metadata["scope_limitations"], ["coarse"])
        self.assertEqual(raised.exception.metadata["scope_provenance"]["entries"][0]["availability"], "unavailable")
        unsupported = {**leaf, "compatibility": {"exact_scope": {"status": "unsupported", "reason": "why"}}}
        with self.assertRaisesRegex(ValueError, "Exact UPID scope is unsupported: s/leaf: why"):
            self.query.raise_if_exact_unavailable([(unsupported, "")], scope, trace_sha256="a" * 64, trace_side="trace_a")

    def test_scope_evidence_claims_the_exact_scope_only_for_available_target_rows(self) -> None:
        gate = identity.IdentityGate(mock.Mock(), mock.Mock())
        gate.resolve = lambda _target: verified()
        scope = gate.apply({"id": "s", "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid"}]},
                           {"upid": 42}, {}).scope
        kwargs = {"trace_sha256": "a" * 64, "trace_side": "trace_a"}
        target = self.query.scope_evidence({"role": "target", "binding": "native_upid"}, scope, "s", [{"x": 1}], **kwargs)
        self.assertEqual(target["applied_process_scope"]["upid"], 42)
        self.assertEqual(target["evidence_role"], "target")
        context = self.query.scope_evidence({"role": "global_context"}, scope, "s", [{"x": 1}], **kwargs)
        self.assertNotIn("applied_process_scope", context)
        self.assertEqual(context["scope_provenance"]["entries"][0]["relative_to"]["upid"], 42)
        mixed = self.query.scope_evidence(
            {"role": "target", "binding": "native_upid", "context_fields": {"peer_context": ["waker"]}},
            scope, "s", [{"x": 1, "waker": "a"}], **kwargs,
        )
        self.assertEqual(mixed["evidence_role"], "mixed")
        self.assertNotIn("applied_process_scope", mixed)
        unavailable = self.query.scope_evidence(
            {"role": "target", "exact_unavailable": "No UPID"}, scope, "s", None, unavailable=True, **kwargs,
        )
        self.assertNotIn("applied_process_scope", unavailable)
        self.assertEqual(unavailable["scope_provenance"]["entries"][0]["reason"], "No UPID")


class ExactExecutionTest(unittest.TestCase):
    """The runner under an exact scope: variants, unavailable evidence, partial results."""

    def setUp(self) -> None:
        load_skill_script("perfetto_skill")
        from runtime.executor import SkillRunner

        self.runner_type = SkillRunner
        self.query_module = load_skill_script("perfetto_query")

    def run_with(self, skill, params, answers, inherited=None):
        calls = []

        def query(query_id, **kwargs):
            calls.append(query_id)
            answer = answers[query_id]
            if isinstance(answer, Exception):
                raise answer
            return answer

        gate = identity.IdentityGate(mock.Mock(), mock.Mock())
        gate.resolve = lambda _target: verified()
        runner = self.runner_type({"skills": {skill["id"]: skill}}, query, identity_gate=gate)
        runner.exact_admission = lambda _skill_id: None
        return runner.run(skill["id"], params, _inherited=inherited), calls

    def unavailable(self):
        error = self.query_module.ExactScopeUnavailable("No UPID relationship exists for this track")
        error.metadata = {"evidence_role": "target"}
        return error

    def test_an_unavailable_step_is_recorded_unobserved_and_the_skill_completes_partial(self) -> None:
        skill = {
            "id": "partial", "type": "composite", "runtime_status": "executable",
            "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid", "type": "integer"}],
            "steps": [
                {"id": "buffer", "type": "atomic", "query_id": "partial/buffer", "save_as": "buffer_rows"},
                {"id": "after", "type": "atomic", "query_id": "partial/after"},
            ],
        }
        result, calls = self.run_with(
            skill, {"upid": 42}, {"partial/buffer": self.unavailable(), "partial/after": [{"v": 1}]},
            inherited={"buffer_rows": {"data": [{"source": "caller"}]}},
        )
        self.assertTrue(result["success"], result)
        self.assertTrue(result["partial"])
        step = result["steps"][0]
        self.assertEqual((step["status"], step["code"]), ("unavailable", "exact_scope_unavailable"))
        self.assertEqual(result["evidence"][0]["status"], "unavailable")
        self.assertEqual(calls, ["partial/buffer", "partial/after"])

    def test_an_unavailable_root_query_fails_the_atomic_skill_as_partial(self) -> None:
        skill = {"id": "root_only", "type": "atomic", "runtime_status": "executable", "query_id": "root_only/root",
                 "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid", "type": "integer"}], "steps": []}
        result, _calls = self.run_with(skill, {"upid": 42}, {"root_only/root": self.unavailable()})
        self.assertFalse(result["success"])
        self.assertTrue(result["partial"])

    def test_an_exact_variant_is_gated_on_its_own_result_dependencies(self) -> None:
        skill = {
            "id": "variant", "type": "composite", "runtime_status": "executable",
            "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid", "type": "integer"}],
            "steps": [{"id": "read", "type": "atomic", "query_id": "variant/read",
                       "result_dependencies": ["named_only"],
                       "exact": {"query_id": "variant/read.exact", "result_dependencies": []}}],
        }
        result, calls = self.run_with(skill, {"upid": 42}, {"variant/read": [{"v": 1}]})
        self.assertEqual(result["steps"][0]["status"], "observed")
        self.assertEqual(calls, ["variant/read"])
        named, _ = self.run_with(skill, {}, {"variant/read": [{"v": 1}]})
        self.assertEqual(named["steps"][0]["status"], "skipped_empty_dependency")

    def test_an_iterator_item_upid_runs_its_detail_skill_exactly(self) -> None:
        # anr_analysis -> anr_detail: each ANR row hands its own upid to the detail Skill.
        detail = {"id": "detail", "type": "atomic", "runtime_status": "executable", "query_id": "detail/root",
                  "identity": {"policy": "verify_if_present", "aliases": ["process_name"]},
                  "inputs": [{"name": "upid", "type": "integer"}, {"name": "pid", "type": "integer"},
                             {"name": "process_name", "type": "string"}], "steps": []}
        parent = {"id": "events", "type": "composite", "runtime_status": "executable",
                  "identity": {"policy": "none"}, "inputs": [], "steps": [
                      {"id": "rows", "type": "atomic", "query_id": "events/rows", "save_as": "rows"},
                      {"id": "each", "type": "iterator", "source": "rows", "item_skill": "detail",
                       "item_params": {"upid": "upid", "pid": "pid", "process_name": "process_name"}},
                  ]}
        seen = []

        def query(query_id, **kwargs):
            seen.append((query_id, kwargs.get("identity_scope")))
            if query_id == "events/rows":
                return [{"upid": 42, "pid": 4242, "process_name": "com.example"}]
            return [{"v": 1}]

        gate = identity.IdentityGate(mock.Mock(), mock.Mock())
        gate.resolve = lambda _target: verified()
        runner = self.runner_type({"skills": {"events": parent, "detail": detail}}, query,
                                  identity_gate=gate, process_scope_enabled=True)
        runner.exact_admission = lambda _skill_id: None
        result = runner.run("events", {})
        self.assertTrue(result["success"], result)
        item = result["steps"][1]["items"][0]["result"]
        self.assertEqual(item["status"], "completed", item.get("error"))
        self.assertEqual((item["params"]["upid"], item["params"]["pid"]), (42, 4242))
        detail_scope = seen[-1][1]
        self.assertEqual((seen[-1][0], detail_scope.mode, detail_scope.upid), ("detail/root", "exact_upid", 42))

    def test_scope_limitations_make_every_enclosing_result_partial(self) -> None:
        # SmartPerfetto's resultScopeLimitations: anr_detail's logcat step declares
        # a limitation, so anr_detail and anr_analysis above it are partial.
        detail = {"id": "detail", "type": "composite", "runtime_status": "executable", "inputs": [], "steps": [
            {"id": "logcat", "type": "atomic", "query_id": "detail/logcat"},
            {"id": "flaky", "type": "atomic", "query_id": "detail/flaky", "optional": True},
        ]}
        parent = {"id": "events", "type": "composite", "runtime_status": "executable", "inputs": [], "steps": [
            {"id": "rows", "type": "atomic", "query_id": "events/rows", "save_as": "rows"},
            {"id": "each", "type": "iterator", "source": "rows", "item_skill": "detail"},
            {"id": "once", "type": "skill", "skill": "detail"},
        ]}
        flaky = RuntimeError("query failed")
        flaky.scope_metadata = {"evidence_role": "target", "scope_limitations": ["optional limit"]}

        def query(query_id, **_kwargs):
            if query_id == "events/rows":
                return {"rows": [{"x": 1}], "metadata": {}}
            if query_id == "detail/flaky":
                raise flaky
            return {"rows": [{"line": "a"}], "metadata": {"scope_limitations": ["Logcat is correlated"]}}

        runner = self.runner_type({"skills": {"events": parent, "detail": detail}}, query)
        child = runner.run("detail", {})
        self.assertEqual((child["success"], child["partial"]), (True, True))
        self.assertEqual(child["scope_limitations"], ["Logcat is correlated", "optional limit"])
        self.assertEqual(child["evidence"][1]["scope_limitations"], ["optional limit"])
        result = runner.run("events", {})
        self.assertTrue(result["partial"])
        self.assertEqual(result["scope_limitations"], ["Logcat is correlated", "optional limit"])
        runner.skills["clean"] = {"id": "clean", "type": "composite", "runtime_status": "executable", "inputs": [],
                                  "steps": [{"id": "rows", "type": "atomic", "query_id": "events/rows"}]}
        clean = runner.run("clean", {})
        self.assertNotIn("partial", clean)
        self.assertNotIn("scope_limitations", clean)

    def test_an_unsupported_closure_is_refused_before_any_query(self) -> None:
        skill = {"id": "plain", "type": "atomic", "runtime_status": "executable", "query_id": "plain/root",
                 "identity": {"policy": "verify_if_present"}, "inputs": [{"name": "upid", "type": "integer"}], "steps": []}
        gate = identity.IdentityGate(mock.Mock(), mock.Mock())
        gate.resolve = lambda _target: verified()
        calls = []
        runner = self.runner_type({"skills": {"plain": skill}}, lambda query_id, **_: calls.append(query_id) or [], identity_gate=gate)
        runner.exact_admission = lambda _skill_id: "Exact UPID scope is unsupported: plain: SQL has no process_scope declaration. Use x."
        result = runner.run("plain", {"upid": 42})
        self.assertEqual(result["status"], "identity_blocked")
        self.assertTrue(result["error"].startswith("Exact UPID scope is unsupported: plain"))
        self.assertEqual(calls, [])


class QueryPreflightScopeEvidenceTest(unittest.TestCase):
    def test_a_schema_failure_keeps_the_step_scope_evidence(self) -> None:
        # An optional step whose schema check fails reports its authored
        # limitation, as a failing query does (SmartPerfetto optional_query_error).
        from tests.support import ROOT

        skill_module = load_skill_script("perfetto_skill")
        runner = skill_module.build_runtime_runner(
            ROOT / "fixtures/smoke/api32_startup_warm.perfetto-trace", {}, trace_processor=None, timeout=1,
            max_output_bytes=1, allow_unverified=True, probe={}, trace_side="trace_a",
        )
        with mock.patch.object(skill_module, "verify_manifest_schema", side_effect=RuntimeError("no android_logs")):
            with self.assertRaises(RuntimeError) as raised:
                runner.query_executor("anr_detail/anr_logcat_context", params={}, results={}, prelude=[])
        metadata = raised.exception.scope_metadata
        self.assertEqual(metadata["scope_limitations"], [
            "Logcat rows are correlated by event identifiers or message text and do not establish an exact process instance.",
        ])
        entry = metadata["scope_provenance"]["entries"][0]
        self.assertEqual((entry["availability"], entry["reason"]), ("unavailable", "no android_logs"))


class ExactRecordValidationTest(unittest.TestCase):
    def test_a_stale_supported_record_is_rejected(self) -> None:
        from tests.support import ROOT
        from tools import validate_all_queries as validator

        generated = ROOT / "skills/perfetto-performance-analysis/references/generated"
        shard = json.loads((generated / "runtime/queries/anr_detail.json").read_text(encoding="utf-8"))
        entry = next(item for item in shard["queries"] if item["id"] == "anr_detail/main_thread_quadrant")
        sql = (generated / entry["path"]).read_text(encoding="utf-8")
        self.assertEqual(validator.exact_scope_errors(entry, sql, generated, None), [])
        undeclared = copy.deepcopy(entry)
        del undeclared["process_scope"]
        self.assertEqual(len(validator.exact_scope_errors(undeclared, sql, generated, None)), 1)
        unconsumed = sql.replace("CROSS JOIN effective_target_processes p", "CROSS JOIN process p")
        self.assertNotEqual(unconsumed, sql)
        self.assertIn("Target SQL does not consume effective_target_processes",
                      validator.exact_scope_errors(entry, unconsumed, generated, None)[0])
        base = {"id": "s/read", "compatibility": {"exact_scope": {"status": "supported", "exact_query_id": "s/read.exact"}}}
        records = {"s/read.exact": {"status": "supported", "exact_variant_of": "s/read"}}
        self.assertEqual(validator.exact_scope_errors(base, "", generated, {"s/read.exact"}, records), [])
        stale = {"s/read.exact": {"status": "unsupported", "reason": "why", "exact_variant_of": "s/read"}}
        self.assertEqual(validator.exact_scope_errors(base, "", generated, {"s/read.exact"}, stale),
                         ["exact scope record does not match its variant s/read.exact"])
        foreign = {"s/read.exact": {"status": "supported", "exact_variant_of": "s/other"}}
        self.assertEqual(validator.exact_scope_errors(base, "", generated, {"s/read.exact"}, foreign),
                         ["exact variant s/read.exact does not belong to this query"])
        missing = copy.deepcopy(entry)
        del missing["compatibility"]["exact_scope"]
        self.assertEqual(validator.exact_scope_errors(missing, sql, generated, None), ["exact scope admission record is missing"])


if __name__ == "__main__":
    unittest.main()
