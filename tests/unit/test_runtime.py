from pathlib import Path
import copy
import json
import sys
import tempfile
import unittest
from unittest import mock

from tests.support import SCRIPTS, load_skill_script

if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))


class RuntimeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue((SCRIPTS / "_common.py").is_file(), "scripts/_common.py")
        self.common = load_skill_script("_common")

    def test_explicit_binary_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / "trace_processor_shell"
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            resolved = self.common.resolve_trace_processor(
                str(binary),
                env={},
                path_lookup=lambda _: None,
                cache_binary=Path(tmp) / "missing",
            )
            self.assertEqual(resolved, binary.resolve())

    def test_missing_binary_has_bootstrap_instruction(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(FileNotFoundError, "bootstrap_trace_processor.py"):
                self.common.resolve_trace_processor(
                    None,
                    env={},
                    path_lookup=lambda _: None,
                    cache_binary=Path(tmp) / "missing",
                )

    def test_query_uses_argument_array_and_parses_csv(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "trace processor with spaces"
            binary.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "print('\\\"one\\\",\\\"missing\\\",\\\"ratio\\\"')\n"
                "print('1,\\\"[NULL]\\\",2.5')\n"
                "print('diagnostic', file=sys.stderr)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace with spaces.pftrace"
            trace.write_bytes(b"trace")

            result = self.common.run_query(
                trace,
                sql="SELECT 1;",
                trace_processor=str(binary),
                timeout=5,
            )

            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.command[0], str(binary.resolve()))
            self.assertIn(str(trace.resolve()), result.command)
            self.assertEqual(
                self.common.parse_csv_output(result.stdout),
                [{"one": 1, "missing": None, "ratio": 2.5}],
            )

    def test_malformed_perfetto_csv_is_rejected(self) -> None:
        malformed = (
            '"section","key","value"\n'
            '"metadata","config","name: "android"\n'
            'next line"\n'
        )
        with self.assertRaisesRegex(self.common.QueryError, "non-tabular text"):
            self.common.parse_csv_output(malformed)

    def test_csv_parser_ignores_trace_processor_leading_blank_lines(self) -> None:
        output = '\n\n"startup_id","package"\n1,"com.example"\n'
        self.assertEqual(
            self.common.parse_csv_output(output),
            [{"startup_id": 1, "package": "com.example"}],
        )

    def test_csv_parser_recovers_perfetto_unescaped_json_result_columns(self) -> None:
        output = (
            '"id","quadrant_json","frequency_json"\n'
            '1,"[{"thread":"main","pct":90}]","[{"core":"big","mhz":2000}]"\n'
        )
        self.assertEqual(
            self.common.parse_csv_output(output),
            [
                {
                    "id": 1,
                    "quadrant_json": '[{"thread":"main","pct":90}]',
                    "frequency_json": '[{"core":"big","mhz":2000}]',
                }
            ],
        )

    def test_sql_template_binds_scalars_and_defaults_without_injection(self) -> None:
        rendered = self.common.render_sql_template(
            "WHERE name GLOB '${package}*' AND ts >= ${start_ts} LIMIT ${top_n|30}",
            {"package": "o'hare", "start_ts": 123},
            {},
        )
        self.assertEqual(
            rendered,
            "WHERE name GLOB 'o''hare*' AND ts >= 123 LIMIT 30",
        )

    def test_sql_template_binds_saved_result_as_relation(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT value FROM ${prior_result}",
            {},
            {"prior_result": [{"value": 1}, {"value": 2}]},
        )
        self.assertIn("SELECT 1 AS \"value\"", rendered)
        self.assertIn("UNION ALL", rendered)

    def test_sql_template_resolves_composite_result_field_paths(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT '${target_process.data[0].process_name}' AS name, "
            "${target_process.data[0].upid} AS upid",
            {},
            {"target_process": [{"process_name": "o'hare", "upid": 42}]},
        )
        self.assertEqual(
            rendered,
            "SELECT 'o''hare' AS name, 42 AS upid",
        )

    def test_sql_template_binds_json_array_for_in_clause(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT * FROM cpu WHERE ('${cpu_ids|}' = '' "
            "OR cpu IN (${cpu_ids|}))",
            {"cpu_ids": [4, 5, 6, 7]},
            {},
        )
        self.assertEqual(
            rendered,
            "SELECT * FROM cpu WHERE ('4,5,6,7' = '' "
            "OR cpu IN (4, 5, 6, 7))",
        )

        empty = self.common.render_sql_template(
            "SELECT * FROM cpu WHERE ('${cpu_ids|}' = '' "
            "OR cpu IN (${cpu_ids|}))",
            {"cpu_ids": []},
            {},
        )
        self.assertEqual(
            empty,
            "SELECT * FROM cpu WHERE ('' = '' OR cpu IN (NULL))",
        )

    def test_sql_template_rejects_missing_parameter(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing SQL template value"):
            self.common.render_sql_template("SELECT ${missing}", {}, {})

    def test_sql_template_null_parameter_takes_its_explicit_default(self) -> None:
        # SmartPerfetto skill-system.md §5: a name that resolves to null uses
        # `|default`, then NULL outside quotes and '' inside them.
        rendered = self.common.render_sql_template(
            "WHERE name GLOB '${package|com.*}' AND dur > ${min_dur_ms|1} * 1000000 "
            "AND ts >= ${start_ts} AND tag = '${tag}' AND upid = ${upid|NULL} LIMIT ${top_n|30}",
            {"package": None, "min_dur_ms": None, "start_ts": None, "tag": None, "upid": None, "top_n": None},
            {},
        )
        self.assertEqual(
            rendered,
            "WHERE name GLOB 'com.*' AND dur > 1 * 1000000 "
            "AND ts >= NULL AND tag = '' AND upid = NULL LIMIT 30",
        )

    def test_sql_template_null_saved_result_takes_its_explicit_default(self) -> None:
        rendered = self.common.render_sql_template(
            "SELECT ${r.data[0].x|5}, ${r.data[0].x}, ${gone|7}, ${gone}",
            {"gone": 3},
            {"r": [{"x": None}], "gone": None},
        )
        # A null saved result is still bound: it shadows the same-name input.
        self.assertEqual(rendered, "SELECT 5, NULL, 7, NULL")

    def test_query_output_is_bounded_before_loading_into_memory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            binary = root / "trace_processor_shell"
            binary.write_text(
                "#!/usr/bin/env python3\nprint('x' * 10000)\n",
                encoding="utf-8",
            )
            binary.chmod(0o755)
            trace = root / "trace.pftrace"
            trace.write_bytes(b"trace")
            with self.assertRaisesRegex(self.common.QueryError, "output limit"):
                self.common.run_query(
                    trace,
                    sql="SELECT 1",
                    trace_processor=str(binary),
                    max_output_bytes=100,
                )


class RuntimeProcessScopeTest(unittest.TestCase):
    """Runtime-issued scope is independent of SQL parameters and saved rows."""

    def setUp(self) -> None:
        self.common = load_skill_script("_common")
        self.trace_sha256 = "a" * 64
        self.identity_policy = {
            "policy": "verify_if_present",
            "scope": "process",
            "aliases": ["package", "process_name"],
        }
        self.named_identity = {
            "status": "resolved",
            "policy": "verify_if_present",
            "target": "com.example",
            "upid": 42,
            "pid": 123,
            "process_name": "com.example",
            "lifetime": {"start_ns": 10, "end_ns": 20},
        }

    def bind(self, identity, parameters, *, supplied=None, names=("package",), roles=("target",)):
        return self.common.bind_runtime_process_scope(
            identity,
            identity_policy=self.identity_policy,
            parameters=parameters,
            supplied_parameters=parameters if supplied is None else supplied,
            name_parameters=list(names),
            **({"scope_roles": roles} if roles != ("target",) else {}),
            trace_sha256=self.trace_sha256,
            trace_side="trace_a",
        )

    def render(self, template, parameters, scope, **overrides):
        options = {
            "process_scope": scope,
            "trace_sha256": self.trace_sha256,
            "trace_side": "trace_a",
            **overrides,
        }
        return self.common.render_sql_template(template, parameters, {}, **options)

    def test_verified_named_scope_keeps_name_predicate_and_does_not_claim_exact_upid(self) -> None:
        parameters = {"package": "com.example"}
        scope = self.bind(self.named_identity, parameters)
        sql = self.render(
            "SELECT * FROM process WHERE (${__process_scope.upid} IS NULL "
            "OR upid = ${__process_scope.upid}) AND name = '${package}'",
            parameters,
            scope,
        )
        self.assertEqual(
            sql,
            "SELECT * FROM process WHERE (NULL IS NULL OR upid = NULL) "
            "AND name = 'com.example'",
        )

    def test_explicit_unscoped_resolution_can_bind_null_with_only_unsupplied_defaults(self) -> None:
        for default in (0, None):
            with self.subTest(default=default):
                parameters = {"package": None, "upid": default, "pid": default}
                scope = self.bind(
                    {"status": "not_requested", "policy": "verify_if_present"},
                    parameters,
                    supplied={},
                )
                self.assertEqual(
                    self.render("SELECT ${__process_scope.upid} AS upid", parameters, scope),
                    "SELECT NULL AS upid",
                )

    def test_required_identity_cannot_issue_unscoped_scope(self) -> None:
        self.identity_policy["policy"] = "required"
        with self.assertRaises(ValueError):
            self.bind({"status": "not_requested", "policy": "required"}, {})

    def test_unknown_and_failed_identity_never_become_default_null(self) -> None:
        for status in ("not_checked", "unknown", "not_found", "ambiguous", "error"):
            with self.subTest(status=status):
                with self.assertRaises(ValueError):
                    self.bind({**self.named_identity, "status": status}, {"package": "com.example"})

    def test_named_resolution_requires_a_matching_name_consumed_by_this_query(self) -> None:
        cases = (
            ({}, ("package",)),
            ({"package": None}, ("package",)),
            ({"package": ""}, ("package",)),
            ({"package": "different"}, ("package",)),
            ({"process_name": "com.example"}, ("package",)),
            ({"package": "com.example"}, ()),
            ({"package": "com.example", "process_name": "different"}, ("package", "process_name")),
        )
        for parameters, names in cases:
            with self.subTest(parameters=parameters, names=names):
                with self.assertRaises(ValueError):
                    self.bind(self.named_identity, parameters, names=names)

    def test_explicit_exact_selectors_are_unavailable_and_invalid_ids_are_not_defaults(self) -> None:
        for selector in ("upid", "pid"):
            for value in (42, 0, -1, None):
                with self.subTest(selector=selector, value=value):
                    with self.assertRaises(ValueError):
                        self.bind(
                            self.named_identity,
                            {"package": "com.example", selector: value},
                        )

    def test_missing_scope_cannot_be_replaced_by_a_template_default(self) -> None:
        for template in ("SELECT ${__process_scope.upid}", "SELECT ${__process_scope.upid|null}"):
            with self.subTest(template=template):
                with self.assertRaises(ValueError):
                    self.common.render_sql_template(template, {}, {})

    def test_reserved_root_dot_and_bracket_aliases_cannot_be_parameters_or_results(self) -> None:
        for key in ("__process_scope", "__process_scope.upid", "__process_scope['upid']", "__process_scope[0]"):
            for location in ("parameters", "results"):
                with self.subTest(key=key, location=location):
                    values = {key: {"upid": None} if key == "__process_scope" else None}
                    with self.assertRaises(ValueError):
                        self.common.render_sql_template(
                            "SELECT ${__process_scope.upid|null}",
                            values if location == "parameters" else {},
                            values if location == "results" else {},
                        )

    def test_scope_requires_the_issued_object_and_current_trace_and_side(self) -> None:
        parameters = {"package": "com.example"}
        scope = self.bind(self.named_identity, parameters)
        forged = json.loads(json.dumps({
            "kind": "named", "upid": None, "target": "com.example",
            "trace_sha256": self.trace_sha256, "trace_side": "trace_a",
        }))
        for candidate in (forged, copy.copy(scope)):
            with self.subTest(candidate=type(candidate).__name__):
                with self.assertRaises(ValueError):
                    self.render("SELECT ${__process_scope.upid}", parameters, candidate)
        for overrides in ({"trace_sha256": "b" * 64}, {"trace_side": "trace_b"}):
            with self.subTest(overrides=overrides):
                with self.assertRaises(ValueError):
                    self.render("SELECT ${__process_scope.upid}", parameters, scope, **overrides)

    def test_issued_scope_does_not_follow_mutable_identity_or_allow_cleared_name_parameter(self) -> None:
        parameters = {"package": "com.example"}
        scope = self.bind(self.named_identity, parameters)
        self.named_identity.update({"target": "other", "upid": 999})
        template = "SELECT ${__process_scope.upid} WHERE name = '${package}'"
        self.assertEqual(
            self.render(template, parameters, scope),
            "SELECT NULL WHERE name = 'com.example'",
        )
        parameters["package"] = ""
        with self.assertRaises(ValueError):
            self.render(template, parameters, scope)

    def test_legacy_queries_and_ordinary_strings_do_not_require_scope(self) -> None:
        self.assertEqual(
            self.common.render_sql_template(
                "SELECT ${upid|0}, '${note}' -- ${__process_scope.upid}\n",
                {"note": "text mentioning __process_scope", "upid": 0},
                {},
            ),
            "SELECT 0, 'text mentioning __process_scope' -- ${__process_scope.upid}\n",
        )

    def test_named_scope_cannot_lose_its_sql_name_or_be_shadowed_by_saved_results(self) -> None:
        parameters = {"package": "com.example"}
        scope = self.bind(self.named_identity, parameters)
        with self.assertRaises(ValueError):
            self.render("SELECT ${__process_scope.upid}", parameters, scope)
        with self.assertRaises(ValueError):
            self.common.render_sql_template(
                "SELECT ${__process_scope.upid} WHERE name = '${package}'",
                parameters, {"package": [{"name": "different"}]},
                process_scope=scope, trace_sha256=self.trace_sha256, trace_side="trace_a",
            )

    def test_context_roles_keep_resolved_identity_without_claiming_a_target_name_predicate(self) -> None:
        parameters = {"package": "com.example"}
        for role in ("global_context", "peer_context", "identity_metadata"):
            with self.subTest(role=role):
                scope = self.bind(self.named_identity, parameters, names=(), roles=(role,))
                self.assertEqual(scope.roles, (role,))
                self.assertEqual(scope.kind, "named")
                self.assertEqual(self.render("SELECT ${__process_scope.upid} AS context_upid", parameters, scope),
                                 "SELECT NULL AS context_upid")
                for status in ("unknown", "not_checked", "ambiguous", "not_found"):
                    with self.subTest(status=status):
                        with self.assertRaises(ValueError):
                            self.bind({**self.named_identity, "status": status}, parameters, names=(), roles=(role,))

    def test_context_role_cannot_supply_the_missing_name_requirement_of_a_target_role(self) -> None:
        with self.assertRaises(ValueError):
            self.bind(self.named_identity, {"package": "com.example"}, names=(), roles=("target", "identity_metadata"))
        with self.assertRaises(ValueError):
            self.bind(self.named_identity, {"package": "com.example"}, roles=("unknown_role",))

    def test_even_an_issued_scope_rejects_reserved_token_defaults(self) -> None:
        parameters = {"package": "com.example"}
        scope = self.bind(self.named_identity, parameters)
        for default in ("99", "null", ""):
            with self.subTest(default=default):
                template = "SELECT ${__process_scope.upid|" + default + "} WHERE name = '${package}'"
                with self.assertRaises(ValueError):
                    self.render(template, parameters, scope)

    def test_reserved_default_text_in_comments_or_parameter_values_is_not_an_active_token(self) -> None:
        template = "SELECT '${note}' AS note -- ${__process_scope.upid|99}\n"
        self.assertEqual(self.common.runtime_sql_bindings(template), [])
        self.assertEqual(
            self.common.render_sql_template(template, {"note": "${__process_scope.upid|99}"}, {}),
            "SELECT '${__process_scope.upid|99}' AS note -- ${__process_scope.upid|99}\n",
        )


class SkillInputContractTest(unittest.TestCase):
    """A supplied parameter the Skill does not declare must never be ignored."""

    def setUp(self) -> None:
        from runtime.executor import SkillRunner

        self.runner_type = SkillRunner
        self.skills = {
            "fps": {
                "id": "fps", "runtime_status": "executable", "type": "atomic",
                "query_id": "fps/root", "identity": {"policy": "none"},
                "inputs": [
                    {"name": "package", "type": "string", "required": False},
                    {"name": "start_ts", "type": "timestamp", "required": False},
                ],
            },
            "frame": {
                "id": "frame", "runtime_status": "executable", "type": "atomic",
                "query_id": "frame/root",
                "identity": {"policy": "verify_if_present", "aliases": ["package", "process_name"]},
                "inputs": [{"name": "package", "type": "string", "required": False}],
            },
        }

    def runner(self, skills, query, **kwargs):
        return self.runner_type({"skills": skills}, query, **kwargs)

    def with_parent(self, steps, inputs=()):
        skills = copy.deepcopy(self.skills)
        skills["parent"] = {
            "id": "parent", "runtime_status": "executable", "type": "composite",
            "inputs": list(inputs), "steps": steps,
        }
        return skills

    def with_iterator(self, item_skill, **step):
        return self.with_parent([
            {"id": "items", "type": "atomic", "query_id": "parent/items", "save_as": "items"},
            {"id": "iter", "type": "iterator", "source": "items", "item_skill": item_skill, **step},
        ])

    def test_unset_optional_input_renders_its_sql_default(self) -> None:
        common = load_skill_script("_common")
        rendered = []

        def query(query_id, *, params, results, **_kwargs):
            rendered.append(common.render_sql_template(
                "WHERE ts >= ${start_ts|0} AND name = '${package}'", params, results,
            ))
            return [{"value": 1}]

        result = self.runner(self.skills, query).run("fps")
        self.assertTrue(result["success"])
        self.assertEqual(rendered, ["WHERE ts >= 0 AND name = ''"])

    def test_undeclared_parameter_is_rejected_before_any_trace_work(self) -> None:
        query = mock.Mock(return_value=[{"value": 1}])
        resolver = mock.Mock(return_value={"status": "exempt"})
        prerequisite = mock.Mock(return_value={"status": "satisfied", "missing": []})
        runner = self.runner(
            self.skills, query, identity_resolver=resolver, prerequisite_checker=prerequisite,
        )
        with self.assertRaisesRegex(ValueError, r"fps.*undeclared.*frame_rate.*declared inputs: package, start_ts"):
            runner.run("fps", {"package": "com.example", "frame_rate": 60})
        query.assert_not_called()
        resolver.assert_not_called()
        prerequisite.assert_not_called()

    def test_identity_alias_without_bound_input_names_the_bound_input(self) -> None:
        for params in ({"process_name": "com.example"}, {"process_name": "com.example", "package": "com.example"}):
            with self.subTest(params=params):
                query = mock.Mock(return_value=[{"value": 1}])
                resolver = mock.Mock(return_value={"status": "resolved", "target": "com.example"})
                runner = self.runner(self.skills, query, identity_resolver=resolver)
                with self.assertRaisesRegex(
                    ValueError, r"frame.*identity alias process_name.*not bound.*pass the value as package",
                ):
                    runner.run("frame", params)
                query.assert_not_called()
                resolver.assert_not_called()

    def test_alias_that_is_not_an_identity_alias_of_an_unscoped_skill_is_plainly_undeclared(self) -> None:
        runner = self.runner(self.skills, mock.Mock(return_value=[]))
        with self.assertRaisesRegex(ValueError, r"fps.*undeclared.*process_name.*declared inputs: package, start_ts") as caught:
            runner.run("fps", {"process_name": "com.example"})
        self.assertNotIn("identity alias", str(caught.exception))

    def test_declared_inputs_still_run(self) -> None:
        query = mock.Mock(return_value=[{"value": 1}])
        result = self.runner(self.skills, query).run("frame", {"package": "com.example"})
        self.assertTrue(result["success"])
        self.assertEqual(query.call_args.kwargs["params"], {"package": "com.example"})

    def test_child_skill_call_with_undeclared_parameter_is_an_explicit_step_error(self) -> None:
        for optional in (True, False):
            with self.subTest(optional=optional):
                skills = self.with_parent(
                    [{
                        "id": "child", "type": "skill", "skill": "fps", "optional": optional,
                        "params": {"start_ts": "${start_ts}", "end_ts": "${start_ts}"},
                    }],
                    inputs=[{"name": "start_ts", "type": "timestamp", "required": False}],
                )
                query = mock.Mock(return_value=[{"value": 1}])
                result = self.runner(skills, query).run("parent", {"start_ts": 5})
                step = result["steps"][0]
                self.assertEqual(step["status"], "error")
                self.assertEqual(step["child"]["status"], "input_rejected")
                self.assertIn("end_ts", step["child"]["error"])
                self.assertEqual(result["success"], optional)
                query.assert_not_called()

    def test_iterator_item_with_undeclared_mapping_fails_that_item(self) -> None:
        skills = self.with_iterator("frame", item_params={"process_name": "name"})

        def query(query_id, **_kwargs):
            return [{"name": "com.example"}] if query_id == "parent/items" else [{"value": 1}]

        result = self.runner(skills, query).run("parent")
        iterator = result["steps"][1]
        self.assertFalse(result["success"])
        self.assertEqual(iterator["failed_items"], 1)
        self.assertEqual(iterator["items"][0]["result"]["status"], "input_rejected")

    def test_iterator_without_item_params_binds_only_declared_row_fields(self) -> None:
        skills = self.with_iterator("fps")
        calls = []

        def query(query_id, **kwargs):
            calls.append((query_id, kwargs["params"]))
            return [{"package": "com.example", "dur": 3}] if query_id == "parent/items" else [{"value": 1}]

        result = self.runner(skills, query).run("parent")
        self.assertTrue(result["success"])
        self.assertEqual(calls[1], ("fps/root", {"package": "com.example", "start_ts": None}))


class SkillReferenceSaveFromTest(unittest.TestCase):
    """`save_from` binds one named child step; it never falls back to another."""

    CHILD = {
        "id": "child", "runtime_status": "executable", "type": "composite",
        "identity": {"policy": "none"}, "inputs": [],
        "steps": [
            {"id": "overview", "type": "atomic", "query_id": "child/overview"},
            {"id": "detail", "type": "atomic", "query_id": "child/detail", "optional": True},
        ],
    }

    def run_parent(self, detail, **ref):
        from runtime.executor import SkillRunner

        seen = {}

        def query(query_id, **kwargs):
            if query_id == "parent/stale":
                return [{"source": "stale"}]
            if query_id == "parent/probe":
                seen.update(kwargs["results"])
                return []
            if query_id == "child/overview":
                return [{"source": "overview"}]
            if isinstance(detail, Exception):
                raise detail
            return detail

        skills = {
            "child": self.CHILD,
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [],
                "steps": [
                    {"id": "stale", "type": "atomic", "query_id": "parent/stale", "save_as": "picked"},
                    {"id": "ref", "type": "skill", "skill": "child", "save_as": "picked", **ref},
                    {"id": "probe", "type": "atomic", "query_id": "parent/probe"},
                ],
            },
        }
        result = SkillRunner({"skills": skills}, query).run("parent")
        self.assertTrue(result["success"])
        return seen

    def test_without_save_from_the_first_observed_step_is_bound(self) -> None:
        self.assertEqual(self.run_parent([{"source": "detail"}])["picked"], {"data": [{"source": "overview"}]})

    def test_save_from_binds_the_named_step(self) -> None:
        seen = self.run_parent([{"source": "detail"}], save_from="detail")
        self.assertEqual(seen["picked"], {"data": [{"source": "detail"}]})

    def test_save_from_binds_a_genuinely_empty_step_as_empty(self) -> None:
        self.assertEqual(self.run_parent([], save_from="detail")["picked"], {"data": []})

    def test_save_from_leaves_the_variable_unbound_when_the_step_did_not_observe(self) -> None:
        for detail, save_from in ((RuntimeError("detail failed"), "detail"), ([{"source": "detail"}], "missing")):
            with self.subTest(save_from=save_from):
                self.assertNotIn("picked", self.run_parent(detail, save_from=save_from))

    def test_save_from_does_not_bind_a_failed_nested_skill_that_kept_partial_rows(self) -> None:
        from runtime.executor import SkillRunner

        seen = {}

        def query(query_id, **kwargs):
            if query_id == "partial/rows":
                return [{"source": "partial"}]
            if query_id == "partial/broken":
                raise RuntimeError("required query failed")
            if query_id == "parent/probe":
                seen.update(kwargs["results"])
            return []

        skills = {
            "partial": {
                "id": "partial", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [],
                "steps": [
                    {"id": "rows", "type": "atomic", "query_id": "partial/rows"},
                    {"id": "broken", "type": "atomic", "query_id": "partial/broken"},
                ],
            },
            "child": {**self.CHILD, "steps": [
                {"id": "nested", "type": "skill", "skill": "partial", "optional": True},
            ]},
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [],
                "steps": [
                    {"id": "ref", "type": "skill", "skill": "child", "save_as": "picked", "save_from": "nested"},
                    {"id": "probe", "type": "atomic", "query_id": "parent/probe"},
                ],
            },
        }
        SkillRunner({"skills": skills}, query).run("parent")
        self.assertNotIn("picked", seen)


class JankTopologyBackedBindingTest(unittest.TestCase):
    """jank_frame_detail binds the read step of children that begin with cpu_topology_view.

    The generated definitions run as shipped: the topology reference returns
    rows, as on any real trace, and is the first observed child step, so only
    `save_from` keeps its rows out of migration_data and cluster_load_data.
    """

    READ_QUERIES = {
        "migration_data": "task_migration_in_range/migration_analysis",
        "cluster_load_data": "cpu_cluster_load_in_range/cluster_load",
    }
    TOPOLOGY = [{"cpu_id": 0, "core_type": "little"}, {"cpu_id": 4, "core_type": "big"}]

    def setUp(self) -> None:
        manifests = SCRIPTS.parent / "references/generated/runtime/skills"
        load = lambda skill_id: json.loads((manifests / f"{skill_id}.json").read_text(encoding="utf-8"))
        jank = load("jank_frame_detail")
        steps = [copy.deepcopy(step) for step in jank["steps"] if step["id"] in ("task_migration", "cpu_cluster_load")]
        self.skills = {skill_id: load(skill_id) for skill_id in (
            "task_migration_in_range", "cpu_cluster_load_in_range", "cpu_topology_view")}
        self.skills["parent"] = {
            "id": "parent", "runtime_status": "executable", "type": "composite",
            "identity": {"policy": "none"},
            "inputs": [item for item in jank["inputs"] if item["name"] in ("start_ts", "end_ts", "package")],
            "steps": [*steps, {"id": "probe", "type": "atomic", "query_id": "parent/probe"}],
        }

    def bindings(self, read_rows):
        from runtime.executor import SkillRunner

        seen = {}

        def query(query_id, **kwargs):
            if query_id == "parent/probe":
                seen.update(kwargs["results"])
                return []
            if query_id == "cpu_topology_view/read_topology":
                return self.TOPOLOGY
            if query_id in self.READ_QUERIES.values():
                if isinstance(read_rows, Exception):
                    raise read_rows
                return read_rows
            return []

        result = SkillRunner({"skills": self.skills}, query).run("parent", {"start_ts": 1, "end_ts": 2})
        self.assertTrue(result["success"])
        return seen

    def test_binds_the_read_step_rows(self) -> None:
        rows = [{"source": "read_step"}]
        seen = self.bindings(rows)
        for name in self.READ_QUERIES:
            self.assertEqual(seen[name], {"data": rows})

    def test_binds_an_empty_read_step_as_empty(self) -> None:
        seen = self.bindings([])
        for name in self.READ_QUERIES:
            self.assertEqual(seen[name], {"data": []})

    def test_leaves_the_binding_unbound_when_the_read_step_failed(self) -> None:
        seen = self.bindings(RuntimeError("read step failed"))
        for name in self.READ_QUERIES:
            self.assertNotIn(name, seen)


class InheritedBindingPrecedenceTest(unittest.TestCase):
    """A name resolves to the Skill's own bindings, then its inputs, then the caller's."""

    def run_child(self, child_inputs, child_params, child_steps):
        from runtime.executor import SkillRunner

        seen = {}

        def query(query_id, **kwargs):
            if query_id.startswith("parent/"):
                return [{"source": "caller"}]
            if query_id == "child/probe":
                seen.update(kwargs["results"])
            return [{"source": query_id}]

        skills = {
            "child": {
                "id": "child", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": child_inputs, "steps": child_steps,
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [],
                "steps": [
                    {"id": "x", "type": "atomic", "query_id": "parent/x"},
                    {"id": "y", "type": "atomic", "query_id": "parent/y"},
                    {"id": "call", "type": "skill", "skill": "child", "params": child_params},
                ],
            },
        }
        result = SkillRunner({"skills": skills}, query).run("parent")
        self.assertTrue(result["success"])
        child_steps_out = {step["step_id"]: step for step in result["steps"][-1]["child"]["steps"]}
        return child_steps_out, seen

    def test_inherited_value_never_overwrites_an_input_after_a_step_runs(self) -> None:
        steps, seen = self.run_child(
            [{"name": "x", "type": "string"}],
            {"x": "own"},
            [
                {"id": "first", "type": "atomic", "query_id": "child/first"},
                {"id": "probe", "type": "atomic", "query_id": "child/probe", "condition": "x === 'own'"},
                {"id": "explain", "type": "diagnostic", "rules": [{"condition": "true", "diagnosis": "x=${x}"}]},
            ],
        )
        self.assertEqual(steps["probe"]["status"], "observed")
        self.assertEqual(steps["explain"]["diagnostics"][0]["diagnosis"], "x=own")
        # SQL binds results ahead of inputs, so the shadowed caller value must not be offered.
        self.assertNotIn("x", seen)
        self.assertIn("y", seen)

    def test_own_step_and_save_as_bindings_still_shadow_an_input(self) -> None:
        steps, seen = self.run_child(
            [{"name": "x", "type": "string"}],
            {"x": "own"},
            [
                {"id": "first", "type": "atomic", "query_id": "child/first", "save_as": "x"},
                {"id": "probe", "type": "atomic", "query_id": "child/probe", "condition": "x.data[0].source === 'child/first'"},
            ],
        )
        self.assertEqual(steps["probe"]["status"], "observed")
        self.assertEqual(seen["x"], {"data": [{"source": "child/first"}]})

    def test_unset_optional_input_does_not_hide_the_caller_value_but_a_default_does(self) -> None:
        steps, seen = self.run_child(
            [{"name": "x", "type": "string"}, {"name": "y", "type": "string", "default": "fallback"}],
            {},
            [
                {"id": "caller_x", "type": "diagnostic", "rules": [
                    {"condition": "x.data[0].source === 'caller'", "diagnosis": "x from caller"},
                ]},
                {"id": "first", "type": "atomic", "query_id": "child/first"},
                {"id": "probe", "type": "atomic", "query_id": "child/probe", "condition": "y === 'fallback'"},
            ],
        )
        self.assertEqual(steps["caller_x"]["status"], "observed")
        self.assertEqual(steps["probe"]["status"], "observed")
        self.assertEqual(seen["x"], {"data": [{"source": "caller"}]})
        self.assertNotIn("y", seen)


if __name__ == "__main__":
    unittest.main()
