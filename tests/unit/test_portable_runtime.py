from pathlib import Path
import copy
import json
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

from tests.support import load_skill_script


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "skills" / "perfetto-performance-analysis" / "scripts"
sys.path.insert(0, str(RUNTIME))


class PortableExpressionTest(unittest.TestCase):
    def setUp(self) -> None:
        from runtime.expressions import evaluate, validate

        self.evaluate = evaluate
        self.validate = validate
        self.context = {
            "enabled": True,
            "threshold": 3,
            "rows": {"data": [{"value": 5, "name": "RenderThread"}]},
            "empty": {"data": []},
        }

    def test_safe_expression_subset_covers_authored_step_conditions(self) -> None:
        self.assertTrue(
            self.evaluate(
                "enabled !== false && rows.data?.[0]?.value >= (threshold || 2)",
                self.context,
            )
        )
        self.assertTrue(self.evaluate("rows.data.length > 0", self.context))
        self.assertFalse(self.evaluate("empty.data?.[0]?.value === 1", self.context))
        self.assertTrue(self.evaluate("(rows.data[0].name || '').includes('Thread')", self.context))

    def test_expression_validator_rejects_code_execution(self) -> None:
        with self.assertRaises(ValueError):
            self.validate("__import__('os').system('id')")

    def test_placeholder_arithmetic_preserves_integer_precision_and_precedence(self) -> None:
        context = {"anr_ts": 9_007_199_254_742_101, "timeout_ns": 800_000_000}
        cases = (
            ("${anr_ts - timeout_ns}", 9_007_198_454_742_101, int),
            ("${anr_ts + 2}", 9_007_199_254_742_103, int),
            ("${anr_ts * 3}", 27_021_597_764_226_303, int),
            ("${(7 + 5) * 3 - 2}", 34, int),
            ("${9 / 2}", 4.5, float),
            ("${9 % 4}", 1, int),
            ("${-3 + +5}", 2, int),
        )
        for expression, expected, result_type in cases:
            with self.subTest(expression=expression):
                result = self.evaluate(expression, context)
                self.assertEqual(result, expected)
                self.assertIs(type(result), result_type)

    def test_placeholder_paths_defaults_and_strings_remain_values(self) -> None:
        context = {
            **self.context, "zero": 0, "disabled": False, "absent": None,
            "text": "${anr_ts - timeout_ns}",
        }
        cases = (
            ("${threshold}", 3),
            ("${rows.data[0].value}", 5),
            ("${empty.data?.[0]?.value}", None),
            ("${missing}", None),
            ("${missing.path}", None),
            ("${zero|99}", 0),
            ("${disabled|true}", False),
            ("${absent|null}", None),
            ("${missing?.value|7}", 7),
            ("${missing|false}", False),
            ("${missing|raw + default}", "raw + default"),
            ("${missing|}", ""),
            ('${missing|"${anr_ts - timeout_ns}"}', "${anr_ts - timeout_ns}"),
            ("${text}", "${anr_ts - timeout_ns}"),
            ('${"literal } | ${not_a_lookup}"}', "literal } | ${not_a_lookup}"),
            (r'${"escaped \" } | quote"}', 'escaped " } | quote'),
            ("${(threshold || 2) + 1}", 4),
            ("${0}", 0),
            ("${false}", False),
        )
        for expression, expected in cases:
            with self.subTest(expression=expression):
                result = self.evaluate(expression, context)
                self.assertEqual(result, expected)
                self.assertIs(type(result), type(expected))

    def test_placeholder_scanner_is_shared_with_text_interpolation(self) -> None:
        from runtime.expressions import interpolate

        source = 'value=${"literal } | ${not_a_lookup}"}; next=${threshold + 2}'
        self.assertEqual(interpolate(source, self.context), "value=literal } | ${not_a_lookup}; next=5")
        self.assertEqual(interpolate("value=${text}", {"text": "${missing + 1}"}), "value=${missing + 1}")
        self.assertEqual(interpolate('${missing|"${threshold}"}', self.context), "${threshold}")

    def test_placeholder_arithmetic_rejects_invalid_operands_and_results(self) -> None:
        for value in (None, False, True, "7", float("nan"), float("inf"), -float("inf")):
            for expression in ("${value + 1}", "${1 - value}", "${+value}", "${-value}"):
                with self.subTest(value=value, expression=expression):
                    with self.assertRaises(ValueError):
                        self.evaluate(expression, {"value": value})
        for expression in (
            "${missing + 1}", "${missing + 1|99}", "${1e308 * 1e308}",
            "${1 / 0}", "${1 % 0}",
            "${rows.data.filter(item => item.value - missing).length}",
        ):
            with self.subTest(expression=expression):
                with self.assertRaises(ValueError):
                    self.evaluate(expression, self.context)

    def test_placeholder_short_circuit_and_outer_condition_semantics_remain_bounded(self) -> None:
        self.assertFalse(self.evaluate("${false && missing + 1}", {}))
        self.assertTrue(self.evaluate("${true || missing + 1}", {}))
        self.assertEqual(self.evaluate("${rows.data.filter(item => item.value - 4).length}", self.context), 1)
        self.assertEqual(self.evaluate("missing + 1", {}), 1)
        self.assertEqual(self.evaluate("-missing", {}), 0)

    def test_placeholder_rejects_invalid_syntax_and_nested_execution(self) -> None:
        for expression in (
            "${threshold +}", "${threshold + 1", "${threshold; 1}",
            "${__import__('os').system('id')}", "${${threshold} + 1}",
            "${(threshold + 1}|3}",
        ):
            with self.subTest(expression=expression):
                with self.assertRaises(ValueError):
                    self.evaluate(expression, self.context)


class ManifestPlaceholderParameterTest(unittest.TestCase):
    """Check real ANR parameter declarations at the runner's child-query boundary."""

    def setUp(self) -> None:
        from runtime.executor import SkillRunner

        self.runner_type = SkillRunner
        manifests = RUNTIME.parent / "references/generated/runtime/skills"
        self.parent = json.loads((manifests / "anr_detail.json").read_text(encoding="utf-8"))
        self.step = copy.deepcopy(next(step for step in self.parent["steps"] if step["id"] == "blocking_reasons"))
        self.child = json.loads((manifests / f"{self.step['skill']}.json").read_text(encoding="utf-8"))
        self.parent["steps"] = [self.step]
        self.manifest = {"skills": {self.parent["id"]: self.parent, self.child["id"]: self.child}}
        self.params = {
            "anr_ts": 9_007_199_254_742_101, "timeout_ns": 800_000_000,
            "process_name": "com.example", "pid": 123, "anr_type": "INPUT_DISPATCHING_TIMEOUT",
        }

    def test_real_anr_mapping_passes_exact_integer_window_to_child(self) -> None:
        query = mock.Mock(return_value=[])
        result = self.runner_type(self.manifest, query).run(self.parent["id"], self.params)
        self.assertTrue(result["success"])
        query.assert_called_once()
        self.assertEqual(query.call_args.args, (self.child["query_id"],))
        params = query.call_args.kwargs["params"]
        self.assertEqual(params["start_ts"], 9_007_198_454_742_101)
        self.assertEqual(params["end_ts"], 9_007_199_254_742_101)
        self.assertIs(type(params["start_ts"]), int)
        self.assertIs(type(params["end_ts"]), int)
        self.assertGreater(params["start_ts"], 0)
        self.assertEqual(params["package"], self.params["process_name"])
        self.assertEqual(params["top_k"], self.step["params"]["top_k"])
        self.assertTrue(set(self.step["params"]).issubset(params))

    def test_invalid_parent_window_never_reaches_child_query(self) -> None:
        for value in (None, False, "7", float("nan"), float("inf"), -float("inf")):
            with self.subTest(value=value):
                query = mock.Mock(return_value=[])
                with self.assertRaises(ValueError):
                    self.runner_type(self.manifest, query).run(
                        self.parent["id"], {**self.params, "timeout_ns": value},
                    )
                query.assert_not_called()
        query = mock.Mock(return_value=[])
        params = {key: value for key, value in self.params.items() if key != "timeout_ns"}
        with self.assertRaises(ValueError):
            self.runner_type(self.manifest, query).run(self.parent["id"], params)
        query.assert_not_called()

    def test_anr_edge_preserves_reserved_namespace_rejection(self) -> None:
        for alias in ("__process_scope", "__process_scope.upid", "__process_scope['upid']"):
            for location in ("params", "inherited", "step_id", "save_as"):
                with self.subTest(alias=alias, location=location):
                    manifest = copy.deepcopy(self.manifest)
                    params, inherited = dict(self.params), {}
                    if location == "params":
                        params[alias] = {"upid": 42}
                    elif location == "inherited":
                        inherited[alias] = {"upid": 42}
                    else:
                        step = manifest["skills"][self.parent["id"]]["steps"][0]
                        step["id" if location == "step_id" else "save_as"] = alias
                    query = mock.Mock(return_value=[])
                    with self.assertRaises(ValueError):
                        self.runner_type(manifest, query).run(self.parent["id"], params, _inherited=inherited)
                    query.assert_not_called()


class PortableRunnerTest(unittest.TestCase):
    def test_runner_preserves_empty_error_child_iterator_diagnostic_and_ai_states(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {
            "skills": {
                "child": {
                    "id": "child",
                    "runtime_status": "executable",
                    "type": "atomic",
                    "inputs": [],
                    "query_id": "child/root",
                },
                "parent": {
                    "id": "parent",
                    "runtime_status": "executable",
                    "type": "composite",
                    "inputs": [{"name": "enabled", "type": "boolean", "required": False, "default": True}],
                    "steps": [
                        {"id": "seed", "type": "atomic", "query_id": "parent/seed", "save_as": "seed"},
                        {"id": "conditional", "type": "atomic", "query_id": "parent/conditional", "condition": "enabled && seed.data[0]?.run === 1"},
                        {"id": "empty", "type": "atomic", "query_id": "parent/empty", "on_empty": "nothing observed"},
                        {"id": "optional_error", "type": "atomic", "query_id": "parent/error", "optional": True},
                        {"id": "child", "type": "skill", "skill": "child", "save_as": "child_rows"},
                        {"id": "items", "type": "atomic", "query_id": "parent/items", "save_as": "items"},
                        {"id": "iter", "type": "iterator", "source": "items", "item_skill": "child", "max_items": 1},
                        {"id": "diagnose", "type": "diagnostic", "inputs": ["child_rows"], "rules": [{"condition": "child_rows.data[0]?.value === 2", "diagnosis": "confirmed", "confidence": "high"}]},
                        {"id": "summary", "type": "ai_summary"},
                    ],
                },
            }
        }

        def query(query_id, **_kwargs):
            if query_id == "parent/error":
                raise RuntimeError("query failed")
            return {
                "parent/seed": [{"run": 1}],
                "parent/conditional": [{"ok": 1}],
                "parent/empty": [],
                "parent/items": [{"item": 1}, {"item": 2}],
                "child/root": [{"value": 2}],
            }[query_id]

        first = SkillRunner(manifest, query).run("parent", {"enabled": True})
        second = SkillRunner(manifest, query).run("parent", {"enabled": True})
        by_id = {step["step_id"]: step for step in first["steps"]}
        self.assertTrue(first["success"])
        self.assertEqual(by_id["empty"]["status"], "empty")
        self.assertEqual(by_id["empty"]["message"], "nothing observed")
        self.assertEqual(by_id["optional_error"]["status"], "error")
        self.assertTrue(by_id["optional_error"]["optional"])
        self.assertEqual(len(by_id["iter"]["items"]), 1)
        self.assertEqual(by_id["diagnose"]["diagnostics"][0]["diagnosis"], "confirmed")
        self.assertEqual(by_id["summary"]["status"], "agent_action_required")
        self.assertEqual(first["evidence"][0]["evidence_id"], second["evidence"][0]["evidence_id"])

    def test_required_iterator_propagates_child_failure(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {"skills": {
            "child": {
                "id": "child", "runtime_status": "executable", "type": "atomic",
                "inputs": [{"name": "item", "type": "integer", "required": True}],
                "query_id": "child/root",
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "inputs": [],
                "steps": [
                    {"id": "items", "type": "atomic", "query_id": "parent/items", "save_as": "items"},
                    {"id": "iter", "type": "iterator", "source": "items", "item_skill": "child", "max_items": 2},
                ],
            },
        }}

        def query(query_id, **_kwargs):
            if query_id == "parent/items":
                return [{"item": 1}, {"item": 2}]
            raise RuntimeError("child query failed")

        result = SkillRunner(manifest, query).run("parent")
        iterator = next(step for step in result["steps"] if step["step_id"] == "iter")
        self.assertFalse(result["success"])
        self.assertEqual(iterator["status"], "error")
        self.assertEqual(iterator["failed_items"], 2)

    def test_optional_child_failure_is_explicit_without_failing_parent(self) -> None:
        from runtime.executor import SkillRunner

        manifest = {"skills": {
            "child": {
                "id": "child", "runtime_status": "executable", "type": "atomic",
                "inputs": [], "query_id": "child/root",
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "inputs": [],
                "steps": [
                    {"id": "child", "type": "skill", "skill": "child", "optional": True},
                ],
            },
        }}

        def query(_query_id, **_kwargs):
            raise RuntimeError("capability unavailable")

        result = SkillRunner(manifest, query).run("parent")
        child = result["steps"][0]
        self.assertTrue(result["success"])
        self.assertEqual(child["status"], "error")
        self.assertTrue(child["optional"])


class PortableProcessScopeRunnerTest(unittest.TestCase):
    def setUp(self) -> None:
        from runtime.executor import SkillRunner

        self.runner_type = SkillRunner
        self.identity = {
            "status": "resolved", "policy": "verify_if_present",
            "target": "com.example", "upid": 42, "pid": 123,
        }
        self.skill = {
            "id": "scoped", "runtime_status": "executable", "type": "atomic",
            "inputs": [{"name": "package", "type": "string", "required": False}],
            "identity": {"policy": "verify_if_present", "aliases": ["package"]},
            "process_scope": {"role": "target", "binding": "effective_target_processes"},
            "query_id": "scoped/root",
        }

    def test_identity_and_raw_supplied_inputs_reach_executor_outside_result_namespace(self) -> None:
        calls = []

        def execute(query_id, **kwargs):
            calls.append((query_id, copy.deepcopy(kwargs)))
            return [{"value": 1}]

        resolver = mock.Mock(return_value=self.identity)
        params = {"package": "com.example", "identity": {"status": "not_requested"}}
        result = self.runner_type(
            {"skills": {"scoped": self.skill}}, execute, identity_resolver=resolver,
        ).run("scoped", params)
        self.assertTrue(result["success"])
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][1].get("identity_result"), self.identity)
        self.assertEqual(calls[0][1].get("supplied_parameters"), params)
        self.assertNotIn("__process_scope", calls[0][1]["params"])
        self.assertNotIn("__process_scope", calls[0][1]["results"])
        resolver.assert_called_once()

    def test_reserved_parameters_inherited_values_and_output_names_are_rejected_before_queries(self) -> None:
        for alias in ("__process_scope", "__process_scope.upid", "__process_scope['upid']"):
            for location in ("params", "inherited", "save_as", "step_id"):
                with self.subTest(alias=alias, location=location):
                    skill = copy.deepcopy(self.skill)
                    skill["type"] = "composite"
                    skill["steps"] = [{"id": "query", "type": "atomic", "query_id": "scoped/root"}]
                    params = {"package": "com.example"}
                    inherited = {}
                    if location == "params":
                        params[alias] = {"upid": None}
                    elif location == "inherited":
                        inherited[alias] = {"data": [{"upid": None}]}
                    else:
                        skill["steps"][0]["save_as" if location == "save_as" else "id"] = alias
                    query = mock.Mock(return_value=[{"value": 1}])
                    runner = self.runner_type(
                        {"skills": {"scoped": skill}}, query,
                        identity_resolver=lambda *_args: self.identity,
                    )
                    with self.assertRaises(ValueError):
                        runner.run("scoped", params, _inherited=inherited)
                    query.assert_not_called()


class ManifestProcessScopeExecutionTest(unittest.TestCase):
    """Exercise adapter identity/binding/setup; isolate TP I/O and capability gates."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.generated = self.root / "references/generated"
        self.generated.mkdir(parents=True)
        self.trace = self.root / "trace.pftrace"
        self.trace.write_bytes(b"scope fixture trace identity")
        self.adapter = load_skill_script("perfetto_skill")
        import _common

        self.common = _common
        self.identity_policy = {
            "policy": "verify_if_present", "scope": "process",
            "aliases": ["package", "process_name"],
        }
        self.skill = {
            "id": "scoped", "type": "atomic", "runtime_status": "executable",
            "query_id": "scoped/root", "identity": self.identity_policy,
            "inputs": [
                {"name": "package", "type": "string", "required": False},
                {"name": "process_name", "type": "string", "required": False},
                {"name": "upid", "type": "integer", "required": False, "default": 0},
            ],
        }
        self.entries = {}
        self.csv = '"upid","pid","name","start_ts","end_ts"\n42,123,"com.example",10,20\n'

    def add_query(self, step, sql, *, setups=(), names=(), scoped=False):
        relative = f"sql/scoped/{step}.sql"
        path = self.generated / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(sql, encoding="utf-8")
        entry = {
            "id": f"scoped/{step}", "skill_id": "scoped", "step_id": step,
            "path": relative, "sha256": self.common.sha256_file(path),
            "template": {
                "parameters": list(names), "result_dependencies": [], "fragments": [],
                "runtime_bindings": ["__process_scope.upid"] if scoped else [],
                "name_parameters": list(names),
            },
            "identity": copy.deepcopy(self.identity_policy),
            "sql_dependencies": {"declared_modules": [], "required_tables": [], "setup_queries": list(setups)},
            "validation": {"execution_verified": False}, "compatibility": {},
        }
        if scoped:
            entry["process_scope"] = {"role": "target", "binding": "effective_target_processes"}
        self.entries[entry["id"]] = entry

    def write_queries(self):
        runtime = self.generated / "runtime"
        (runtime / "queries").mkdir(parents=True, exist_ok=True)
        (runtime / "sql-index.json").write_text(
            json.dumps({"shards": ["queries/scoped.json"]}), encoding="utf-8",
        )
        (runtime / "queries/scoped.json").write_text(
            json.dumps({"queries": list(self.entries.values())}), encoding="utf-8",
        )

    def run_skill(self, params, *, inherited=None):
        self.write_queries()
        output = SimpleNamespace(stdout=self.csv, stderr="", returncode=0)
        query = mock.Mock(return_value=output)
        with mock.patch.object(self.adapter, "SKILL_ROOT", self.root), mock.patch.object(
            self.adapter, "run_query", query,
        ), mock.patch.object(self.common, "run_query", query), mock.patch.object(
            self.adapter, "validate_query_execution", return_value={"status": "allowed"},
        ), mock.patch.object(self.adapter, "verify_manifest_schema", return_value=set()):
            runner = self.adapter.build_runtime_runner(
                self.trace, {"scoped": self.skill}, trace_processor=None,
                timeout=5, max_output_bytes=4096, allow_unverified=True,
                probe={}, trace_side="trace_a",
            )
            result = runner.run("scoped", params, _inherited=inherited)
        analysis_calls = [
            call.kwargs["sql"] for call in query.call_args_list
            if "/* ANALYSIS_QUERY */" in call.kwargs["sql"]
        ]
        self.identity_query_count = len(query.call_args_list) - len(analysis_calls)
        return result, analysis_calls

    def add_scoped_root(self):
        self.add_query(
            "root", "/* ANALYSIS_QUERY */ SELECT * FROM process "
            "WHERE (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}) "
            "AND ('${package|}' = '' OR name = '${package|}')",
            names=("package",), scoped=True,
        )

    def test_named_and_unscoped_queries_render_real_new_binding_without_an_extra_resolver(self) -> None:
        self.add_scoped_root()
        for params in ({"package": "com.example"}, {}):
            with self.subTest(params=params):
                result, queries = self.run_skill(params)
                self.assertTrue(result["success"], result)
                self.assertEqual(len(queries), 1)
                self.assertEqual(self.identity_query_count, 1 if params else 0)
                self.assertIn("NULL IS NULL OR upid = NULL", queries[0])
                self.assertNotIn("${", queries[0])
                self.assertEqual(
                    result["identity"]["status"], "resolved" if params else "not_requested",
                )
                if params:
                    self.assertIn("name = 'com.example'", queries[0])

    def test_ambiguous_identity_and_explicit_exact_or_invalid_selector_do_not_execute_sql(self) -> None:
        self.add_scoped_root()
        for value in (42, 0, -1, None):
            with self.subTest(upid=value):
                result, queries = self.run_skill({"package": "com.example", "upid": value})
                self.assertFalse(result["success"])
                self.assertEqual(queries, [])
        self.csv += '43,124,"com.example",21,30\n'
        result, queries = self.run_skill({"package": "com.example"})
        self.assertFalse(result["success"])
        self.assertEqual(result["identity"]["status"], "ambiguous")
        self.assertEqual(queries, [])

    def test_setup_only_scope_is_bound_and_retains_setup_name_predicate(self) -> None:
        self.add_query(
            "setup", "CREATE VIEW selected AS SELECT * FROM process "
            "WHERE (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}) "
            "AND name = '${package}';", names=("package",), scoped=True,
        )
        self.add_query(
            "relay", "CREATE VIEW relayed AS SELECT * FROM selected;", setups=("scoped/setup",),
        )
        self.add_query("root", "/* ANALYSIS_QUERY */ SELECT * FROM relayed", setups=("scoped/relay",))
        result, queries = self.run_skill({"package": "com.example"})
        self.assertTrue(result["success"], result)
        self.assertEqual(len(queries), 1)
        self.assertIn("CREATE VIEW selected", queries[0])
        self.assertIn("CREATE VIEW relayed", queries[0])
        self.assertIn("NULL IS NULL OR upid = NULL", queries[0])
        self.assertIn("name = 'com.example'", queries[0])

    def test_setup_name_requirement_cannot_be_omitted_or_conflict_with_leaf_identity(self) -> None:
        self.add_query(
            "setup", "CREATE VIEW selected AS SELECT * FROM process "
            "WHERE (${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid}) "
            "AND ('${package|}' = '' OR name = '${package|}');",
            names=("package",), scoped=True,
        )
        self.add_query(
            "root", "/* ANALYSIS_QUERY */ SELECT * FROM selected "
            "WHERE name = '${process_name}'", setups=("scoped/setup",), names=("process_name",),
        )
        for params in (
            {"process_name": "com.example"},
            {"package": "com.example", "process_name": "different"},
        ):
            with self.subTest(params=params):
                result, queries = self.run_skill(params)
                self.assertFalse(result["success"])
                self.assertEqual(queries, [])

    def test_two_setup_queries_with_conflicting_name_requirements_are_rejected(self) -> None:
        for step, name in (("first", "package"), ("second", "process_name")):
            self.add_query(
                step, "CREATE VIEW " + step + " AS SELECT * FROM process "
                "WHERE ${__process_scope.upid} IS NULL AND name = '${" + name + "}';",
                names=(name,), scoped=True,
            )
        self.add_query(
            "root", "/* ANALYSIS_QUERY */ SELECT * FROM first JOIN second",
            setups=("scoped/first", "scoped/second"),
        )
        result, queries = self.run_skill({"package": "com.example", "process_name": "different"})
        self.assertFalse(result["success"])
        self.assertEqual(queries, [])

    def test_legacy_query_without_scope_retains_optional_identity_and_default_behavior(self) -> None:
        self.add_query("root", "/* ANALYSIS_QUERY */ SELECT ${upid|0} AS value")
        self.csv += '43,124,"com.example",21,30\n'
        result, queries = self.run_skill({"package": "com.example", "upid": 0})
        self.assertTrue(result["success"], result)
        self.assertEqual(result["identity"]["status"], "ambiguous")
        self.assertEqual(queries, ["/* ANALYSIS_QUERY */ SELECT 0 AS value"])

    def test_declared_unsupported_exact_branch_cannot_fall_back_to_base_sql(self) -> None:
        self.add_query("root", "/* ANALYSIS_QUERY */ SELECT ${upid|0} AS value")
        self.entries["scoped/root"]["compatibility"]["exact_scope"] = {"status": "unsupported"}
        result, queries = self.run_skill({"upid": 42})
        self.assertFalse(result["success"])
        self.assertEqual(queries, [])

    def test_context_roles_survive_execution_as_context_receipts(self) -> None:
        for role in ("global_context", "peer_context", "identity_metadata"):
            with self.subTest(role=role):
                self.add_query("root", "/* ANALYSIS_QUERY */ SELECT ${__process_scope.upid} AS context_upid", scoped=True)
                declaration = {"role": role, "limitations": ["Context rows do not establish target-process measurements."]}
                self.entries["scoped/root"]["process_scope"] = declaration
                result, queries = self.run_skill({"package": "com.example"})
                self.assertTrue(result["success"], result)
                self.assertEqual(queries, ["/* ANALYSIS_QUERY */ SELECT NULL AS context_upid"])
                self.assertEqual(result["evidence"][0].get("process_scope"), declaration)
                self.assertEqual(result["identity"]["status"], "resolved")
                self.assertFalse(result["evidence"][0]["validation"].get("semantic_verified", False))
                self.assertNotIn("appliedProcessScope", result["evidence"][0])

    def test_identity_metadata_fallback_preserves_exact_unavailable_and_saved_result_input(self) -> None:
        declaration = {
            "role": "identity_metadata",
            "exact_unavailable": "No FrameTimeline evidence is available for this UPID; BufferTX names cannot establish exact frame rate or jank.",
        }
        self.add_query(
            "root", "/* ANALYSIS_QUERY */ SELECT CASE WHEN ${__process_scope.upid} IS NOT NULL "
            "THEN 'unavailable_exact_upid' ELSE '${coverage.data[0].target_process_status}' END AS status, "
            "'${package}' AS requested_package", names=("package",), scoped=True,
        )
        self.entries["scoped/root"]["process_scope"] = declaration
        result, queries = self.run_skill(
            {"package": "com.example"}, inherited={"coverage": {"data": [{"target_process_status": "not_found"}]}},
        )
        self.assertTrue(result["success"], result)
        self.assertEqual(len(queries), 1)
        self.assertIn("WHEN NULL IS NOT NULL", queries[0])
        self.assertIn("ELSE 'not_found'", queries[0])
        self.assertEqual(result["evidence"][0].get("process_scope"), declaration)
        self.assertNotIn("binding", result["evidence"][0]["process_scope"])

    def test_mixed_setup_receipts_keep_roles_and_target_still_needs_its_own_name(self) -> None:
        self.add_query(
            "context", "CREATE VIEW context_rows AS SELECT ${__process_scope.upid} AS context_upid;", scoped=True,
        )
        self.entries["scoped/context"]["process_scope"] = {"role": "identity_metadata"}
        self.add_scoped_root()
        self.entries["scoped/root"]["sql_dependencies"]["setup_queries"] = ["scoped/context"]
        result, queries = self.run_skill({"package": "com.example"})
        self.assertTrue(result["success"], result)
        evidence = result["evidence"][0]
        self.assertEqual(evidence.get("process_scope"), self.entries["scoped/root"]["process_scope"])
        self.assertEqual(evidence.get("setup_process_scopes"), [
            {"query_id": "scoped/context", "process_scope": {"role": "identity_metadata"}},
        ])
        self.assertIn("name = 'com.example'", queries[0])
        self.add_query("root", "/* ANALYSIS_QUERY */ SELECT ${__process_scope.upid} AS target_upid",
                       setups=("scoped/context",), scoped=True)
        result, queries = self.run_skill({"package": "com.example"})
        self.assertFalse(result["success"])
        self.assertEqual(queries, [])

    def test_manifest_query_cli_uses_real_identity_and_rejects_reserved_parameter_or_result(self) -> None:
        self.add_scoped_root()
        self.write_queries()
        cli = load_skill_script("perfetto_query")
        destination = self.root / "result.json"
        args = [str(self.trace), "--query-id", "scoped/root", "--output", str(destination)]
        output = SimpleNamespace(stdout=self.csv, stderr="", returncode=0)
        query = mock.Mock(return_value=output)
        with mock.patch.object(cli, "__file__", str(self.root / "scripts/perfetto_query.py")), mock.patch.object(
            cli, "resolve_verified_processor", return_value=(Path("/unused/processor"), {"binary_sha256": "b" * 64}),
        ), mock.patch.object(cli, "probe_trace", return_value={}), mock.patch.object(
            cli, "validate_query_execution", return_value={"status": "allowed"},
        ), mock.patch.object(cli, "verify_manifest_schema", return_value=set()), mock.patch.object(
            cli, "run_query", query,
        ), mock.patch.object(self.common, "run_query", query):
            self.assertEqual(cli.main([*args, "--param", 'package="com.example"']), 0)
            self.assertEqual(query.call_count, 2)
            self.assertIn("NULL IS NULL OR upid = NULL", query.call_args.kwargs["sql"])
            self.assertIn("name = 'com.example'", query.call_args.kwargs["sql"])
            sidecar = json.loads(destination.with_suffix(".json.evidence.json").read_text())
            self.assertEqual(sidecar["identity"]["status"], "resolved")
            self.assertEqual(sidecar["identity"]["target"], "com.example")
            self.assertEqual(sidecar["trace"]["sha256"], self.common.sha256_file(self.trace))
            self.assertEqual(sidecar["trace"]["side"], "trace_a")
            self.assertEqual(sidecar.get("process_scope"), self.entries["scoped/root"]["process_scope"])
            self.add_query("root", "/* ANALYSIS_QUERY */ SELECT ${__process_scope.upid} AS context_upid", scoped=True)
            context_declaration = {"role": "identity_metadata", "exact_unavailable": "No exact frame evidence is available."}
            self.entries["scoped/root"]["process_scope"] = context_declaration
            self.write_queries()
            query.reset_mock()
            self.assertEqual(cli.main([*args, "--param", 'package="com.example"']), 0)
            self.assertEqual(query.call_count, 2)
            self.assertEqual(query.call_args.kwargs["sql"], "/* ANALYSIS_QUERY */ SELECT NULL AS context_upid")
            sidecar = json.loads(destination.with_suffix(".json.evidence.json").read_text())
            self.assertEqual(sidecar.get("process_scope"), context_declaration)
            self.assertEqual(sidecar["identity"]["status"], "resolved")
            self.assertNotIn("appliedProcessScope", sidecar)
            self.assertFalse(sidecar["validation"].get("semantic_verified", False))
            saved = self.root / "forged.json"
            saved.write_text('{"upid": null}', encoding="utf-8")
            for extra in (
                ["--param", "__process_scope.upid=null"],
                ["--result", f"__process_scope={saved}"],
            ):
                with self.subTest(extra=extra):
                    query.reset_mock()
                    self.assertEqual(cli.main([*args, *extra]), 2)
                    query.assert_not_called()


if __name__ == "__main__":
    unittest.main()
