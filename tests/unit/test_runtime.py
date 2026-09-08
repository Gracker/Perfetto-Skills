from pathlib import Path
import copy
import json
import tempfile
import unittest

from tests.support import SCRIPTS, load_skill_script


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


if __name__ == "__main__":
    unittest.main()
