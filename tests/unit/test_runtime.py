from pathlib import Path
import copy
import json
import re
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

    def test_sql_template_pattern_literal_values_match_themselves(self) -> None:
        # SmartPerfetto sqlTemplate.ts: a value bound into the literal that is
        # the whole GLOB/LIKE pattern is literal text; its author-written
        # wildcards and |default stay patterns.
        render = self.common.render_sql_template
        self.assertEqual(
            render("WHERE p.name = '${package}' OR p.name GLOB '${package}:*'", {"package": "com.foo*"}, {}),
            "WHERE p.name = 'com.foo*' OR p.name GLOB 'com.foo[*]:*'",
        )
        self.assertEqual(
            render("WHERE x NOT glob /* c */ ('*${v}*') COLLATE BINARY", {"v": "a?[b]'"}, {}),
            "WHERE x NOT glob /* c */ ('*a[?][[]b]''*') COLLATE BINARY",
        )
        self.assertEqual(render("WHERE x GLOB '${v|com.*}'", {"v": None}, {}), "WHERE x GLOB 'com.*'")
        self.assertEqual(
            render("WHERE l LIKE 'TX - ${v}%' ESCAPE '\\'", {"v": "a_b%\\"}, {}),
            "WHERE l LIKE 'TX - a\\_b\\%\\\\%' ESCAPE '\\'",
        )
        self.assertEqual(render("WHERE l LIKE '${v}'", {"v": "com.foo"}, {}), "WHERE l LIKE 'com.foo'")
        with self.assertRaisesRegex(ValueError, "without ESCAPE"):
            render("WHERE l LIKE '${v}'", {"v": "com_foo"}, {})

    def test_sql_template_refuses_pattern_expressions_and_quoted_identifiers(self) -> None:
        for template in (
            "WHERE t.name GLOB '*' || LOWER('${v}') || '*'",
            "WHERE msg LIKE '%' ||\n  '${v}'\n  || '%'",
            "WHERE name GLOB LOWER('${v}')",
            "WHERE name GLOB ${v}",
            "WHERE name REGEXP '${v}'",
            "WHERE glob('${v}', name)",
            "WHERE name LIKE 'a%' ESCAPE '${v}'",
        ):
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, "pattern expression"):
                    self.common.render_sql_template(template, {"v": "x"}, {})
        for template in ('SELECT "${v}" FROM t', "SELECT `${v}` FROM t", "SELECT [${v}] FROM t"):
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, "quoted identifier"):
                    self.common.render_sql_template(template, {"v": "x"}, {})
        self.assertEqual(
            self.common.render_sql_template(
                "WHERE a GLOB 'x*' AND b = '${v}' -- ${v}\n", {"v": "o'k"}, {}
            ),
            "WHERE a GLOB 'x*' AND b = 'o''k' -- ${v}\n",
        )
        # A quoted identifier is not a comment opener; the placeholder after it binds.
        self.assertEqual(self.common.render_sql_template('SELECT "--", ${v}', {"v": 1}, {}), 'SELECT "--", 1')
        for template, message in (("SELECT ${", "unterminated"), ("SELECT '${}'", "empty")):
            with self.assertRaisesRegex(ValueError, message):
                self.common.render_sql_template(template, {}, {})

    def test_sql_template_closes_pattern_bypasses(self) -> None:
        render = self.common.render_sql_template
        for template in (
            "WHERE name GLOB CASE WHEN 1 THEN '${v}' ELSE '' END",
            "WHERE name GLOB '${v}' COLLATE BINARY || '${w}'",
            "WHERE \"glob\"('${v}', name)",
            "WHERE `like`('${v}', name)",
            "WHERE name LIKE '${v}' ESCAPE ${e}",
            "WHERE name GLOB '${v}' ESCAPE '\\'",
        ):
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, "pattern expression"):
                    render(template, {"v": "a", "w": "*", "e": 1}, {})
        self.assertEqual(
            render("WHERE a GLOB '${v}' COLLATE NOCASE AND b = CASE WHEN c THEN '${w}' END", {"v": "*", "w": "*"}, {}),
            "WHERE a GLOB '[*]' COLLATE NOCASE AND b = CASE WHEN c THEN '*' END",
        )
        self.assertEqual(render("WHERE n LIKE '${v}' ESCAPE ('1')", {"v": "1a"}, {}), "WHERE n LIKE '11a' ESCAPE ('1')")
        # A quoted name is never a keyword: "END" does not close the CASE, and a column called "glob" is not GLOB.
        for template in (
            "WHERE name GLOB CASE WHEN \"END\" THEN '${v}' ELSE '' END",
            "WHERE name GLOB CASE WHEN [END] THEN '${v}' ELSE '' END",
            "WHERE name GLOB CASE WHEN `END` THEN '${v}' ELSE '' END",
        ):
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, "pattern expression"):
                    render(template, {"v": "*"}, {})
        self.assertEqual(render("SELECT \"glob\" || '${v}' FROM names", {"v": "*"}, {}), "SELECT \"glob\" || '*' FROM names")
        for template, message in (
            ("WHERE n GLOB '[${v}]'", "character class"),
            ("WHERE n GLOB '[^]${v}'", "character class"),
            ("WHERE n LIKE '\\${v}%' ESCAPE '\\'", "ESCAPE character"),
        ):
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, message):
                    render(template, {"v": "a-z"}, {})
        self.assertEqual(render("WHERE n GLOB '[ab]${v}*'", {"v": "x"}, {}), "WHERE n GLOB '[ab]x*'")
        self.assertEqual(render("SELECT 1-${v} AND x = 1", {"v": -1}, {}), "SELECT 1- -1 AND x = 1")

    def test_published_sql_binds_placeholders_only_where_escaping_keeps_them_data(self) -> None:
        # The same rule SmartPerfetto's sqlTemplate.test.ts applies to its Skills,
        # over every SQL file this package ships.
        refused = []
        for path in sorted(SCRIPTS.parent.rglob("*.sql")):
            for start, place in self.common.sql_placeholder_places(path.read_text(encoding="utf-8")).items():
                token = place.token
                if (
                    place.context in {"identifier", "malformed"}
                    or (token is not None and token.in_pattern_expression)
                    or (token is not None and token.pattern == "like" and not token.escape)
                ):
                    refused.append(f"{path.relative_to(SCRIPTS.parent)}@{start}: {place.match}")
        self.assertEqual(refused, [])

    def test_sql_template_pattern_literals_match_only_the_value_in_sqlite(self) -> None:
        import sqlite3

        db = sqlite3.connect(":memory:")
        db.execute("CREATE TABLE names (name TEXT)")
        names = ["com.foo", "com.foo:remote", "com.foox", "com.foo*", "com.foo*:push", "com.f[o]o", "com.fo_"]
        db.executemany("INSERT INTO names VALUES (?)", [(n,) for n in names])

        def matching(predicate: str, value: str) -> list[str]:
            where = self.common.render_sql_template(predicate, {"v": value}, {})
            return [row[0] for row in db.execute(f"SELECT name FROM names WHERE {where} ORDER BY rowid")]

        scope = "name = '${v}' OR name GLOB '${v}:*'"
        self.assertEqual(matching(scope, "com.foo"), ["com.foo", "com.foo:remote"])
        self.assertEqual(matching(scope, "com.foo*"), ["com.foo*", "com.foo*:push"])
        self.assertEqual(matching(scope, "com.f[o]o"), ["com.f[o]o"])
        self.assertEqual(matching("name GLOB '*${v}*'", "?"), [])
        self.assertEqual(matching("name LIKE 'com.f${v}' ESCAPE '\\'", "o_"), ["com.fo_"])
        db.close()

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

    def test_sql_template_empty_saved_result_path_takes_its_explicit_default(self) -> None:
        # SmartPerfetto resolvePath: `data[0]` of an empty result is undefined,
        # so the placeholder takes its `|default` and the step still runs.
        rendered = self.common.render_sql_template(
            "SELECT ${r.data[0].period|16666667}, '${r.data[0].status|}', ${r.data[1].x|0}, ${gone.data[0].x|3}",
            {},
            {"r": {"data": [{"period": 8333333, "status": "ok"}]}},
        )
        self.assertEqual(rendered, "SELECT 8333333, 'ok', 0, 3")
        rendered = self.common.render_sql_template(
            "SELECT ${r.data[0].period|16666667}, ${n.data[0].x|2}", {}, {"r": {"data": []}, "n": None},
        )
        self.assertEqual(rendered, "SELECT 16666667, 2")

    def test_sql_template_unresolvable_saved_result_path_stays_strict(self) -> None:
        cases = (
            ("SELECT ${r.data[0].period}", {"r": {"data": []}}, "out of range"),
            ("SELECT ${r.data[0].typo|0}", {"r": {"data": [{"period": 1}]}}, "no field"),
            ("SELECT ${r.data[0][0]|0}", {"r": {"data": [{"period": 1}]}}, "non-array"),
            ("SELECT ${r.data[0]..x|0}", {"r": {"data": []}}, "invalid saved result path"),
            ("SELECT ${r.data[0]|0}", {"r": {"data": [{"period": 1}]}}, "scalar"),
        )
        for template, results, message in cases:
            with self.subTest(template=template):
                with self.assertRaisesRegex(ValueError, message):
                    self.common.render_sql_template(template, {}, results)

    def test_sql_template_roots_gate_only_on_rows_the_template_cannot_default(self) -> None:
        parameters, references, dependencies = self.common.sql_template_roots(
            "SELECT ${vsync.data[0].period|16666667}, '${strict.data[0].status}', "
            "${mixed.data[0].a|0}, ${mixed.data[0].b}, '${package}', ${__process_scope.upid} "
            "FROM ${relation} JOIN ${relation_default|x} -- ${commented.data[0].x} ${note}\n",
            {"vsync", "relation", "relation_default", "strict", "mixed", "commented", "unused"},
        )
        self.assertEqual(parameters, ["package"])
        self.assertEqual(references, ["mixed", "relation", "relation_default", "strict", "vsync"])
        # A bare relation cannot render without rows, default or not.
        self.assertEqual(dependencies, ["mixed", "relation", "relation_default", "strict"])

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

    def test_empty_saved_result_gates_only_the_steps_that_need_its_rows(self) -> None:
        # memory_analysis/main_thread_gc: a defaulted path to an empty
        # vsync_info runs with its default, as in SmartPerfetto.
        common = load_skill_script("_common")
        templates = {
            "parent/gc": "SELECT dur / ${vsync_info.data[0].period|16666667}",
            "parent/strict": "SELECT '${vsync_info.data[0].status}'",
        }
        rendered = []

        def query(query_id, *, results, **_kwargs):
            if query_id == "parent/vsync":
                return []
            rendered.append(common.render_sql_template(templates[query_id], {}, results))
            return [{"value": 1}]

        skills = self.with_parent([
            {"id": "vsync", "type": "atomic", "query_id": "parent/vsync", "save_as": "vsync_info"},
            {"id": "gc", "type": "atomic", "query_id": "parent/gc", "result_dependencies": []},
            {"id": "strict", "type": "atomic", "query_id": "parent/strict", "result_dependencies": ["vsync_info"]},
        ])
        result = self.runner(skills, query).run("parent")
        self.assertTrue(result["success"])
        self.assertEqual([step["status"] for step in result["steps"]], ["empty", "observed", "skipped_empty_dependency"])
        self.assertEqual(rendered, ["SELECT dur / 16666667"])

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

    def test_without_save_from_the_default_step_is_bound(self) -> None:
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
    rows, as on any real trace. The default selection already skips it (see
    GeneratedDefaultChildSelectionTest); `save_from` also leaves the binding
    unbound when the read step failed, where the default would bind `[]`.
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
        self.frame_diagnosis = next(step for step in jank["steps"] if step["id"] == "frame_diagnosis")
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

    def diagnose(self, migration_rows, cluster_rows):
        """Renders the generated frame_diagnosis rules that read these bindings."""
        from runtime.executor import SkillRunner

        rules = [rule for rule in self.frame_diagnosis["rules"]
                 if any(name in rule["condition"] for name in self.READ_QUERIES)]
        skills = copy.deepcopy(self.skills)
        skills["parent"]["steps"][-1] = {"id": "diagnose", "type": "diagnostic", "rules": rules}
        answers = {self.READ_QUERIES["migration_data"]: migration_rows,
                   self.READ_QUERIES["cluster_load_data"]: cluster_rows}

        def query(query_id, **kwargs):
            if query_id == "cpu_topology_view/read_topology":
                return self.TOPOLOGY
            return answers.get(query_id, [])

        result = SkillRunner({"skills": skills}, query).run("parent", {"start_ts": 1, "end_ts": 2})
        self.assertTrue(result["success"])
        return next(step for step in result["steps"] if step["step_id"] == "diagnose")["diagnostics"]

    def test_migration_and_cluster_hints_render_without_an_unevidenced_cause(self) -> None:
        # The thread with the most migrations is not the UI thread, and every tier is saturated.
        migration = [{"thread_name": "Thread-7", "migration_count": 9, "big_to_little": 5, "little_to_big": 4,
                      "big_core_pct": 20, "unknown_core_ns": 0, "unique_cpus": 6}]
        cluster = [{"cluster": name, "core_count": 2, "load_pct": load, "max_single_core_pct": single}
                   for name, load, single in (("超大核簇", 95, 80), ("大核簇", 95, 99), ("中核簇", 95, 80), ("小核簇", 96, 80))]
        diagnostics = self.diagnose(migration, cluster)
        self.assertEqual([d["diagnosis"] for d in diagnostics], [
            "Thread-7 从大核组（超大/大/中核）迁移到小核 5 次，小核迁回大核组 4 次（迁移次数最多的线程）",
            "Thread-7 大核组（超大/大/中核）运行占比仅 20%",
            "大核簇负载 95%，接近跑满",
            "超大核簇负载 95%，接近跑满",
            "中核簇负载 95%，接近跑满",
            "小核簇负载 96%，几乎跑满",
            "大核簇与小核簇负载均高于 70%: 大核簇 95%, 小核簇 96%",
            "大核簇中有核心接近 100% (99%)",
        ])
        for text in (text for d in diagnostics for text in (d["diagnosis"], *d["suggestions"])):
            self.assertNotRegex(text, r"温控降频|温控策略|温度|过热|散热|UI 线程|资源严重不足|导致调度延迟|整体负载")
        # The migration rules and the big-tier saturation rules defer a frequency cause to the limit evidence.
        deferring = [d["diagnosis"] for d in diagnostics
                     if any("是否限频以本帧的 CPU 限频证据为准" in text for text in d["suggestions"])]
        self.assertEqual(deferring, [diagnostics[index]["diagnosis"] for index in range(5)])


def _skill(skill_id, steps, **extra):
    return {
        "id": skill_id, "runtime_status": "executable", "type": "composite",
        "identity": {"policy": "none"}, "inputs": [], "steps": steps, **extra,
    }


def _run_reference(skills, child_id, answers, *, ref=None, **runner):
    """Run a parent whose `ref` step references `child_id`, then a probe step.

    Returns what the probe sees (the parent's bindings) and the `ref` step record.
    """
    from runtime.executor import SkillRunner

    seen = {}

    def query(query_id, **kwargs):
        if query_id == "parent/probe":
            seen.update(kwargs["results"])
            return []
        answer = answers.get(query_id, [])
        if isinstance(answer, Exception):
            raise answer
        return answer

    parent = _skill("parent", [
        {"id": "ref", "type": "skill", "skill": child_id, **(ref if ref is not None else {"save_as": "picked"})},
        {"id": "probe", "type": "atomic", "query_id": "parent/probe"},
    ])
    result = SkillRunner({"skills": {**skills, "parent": parent}}, query, **runner).run("parent")
    return seen, result["steps"][0]


class DefaultChildSelectionTest(unittest.TestCase):
    """A Skill reference read by default exposes the child step SmartPerfetto selects.

    Root, else the first displayed step with meaningful data, else the first
    step with meaningful data, else the last step holding data, among the steps
    that ran before the first required failure. A nested Skill reference is
    meaningful only through its child's diagnostics, never its rows.
    """

    GRANDCHILD = _skill("grandchild", [{"id": "rows", "type": "atomic", "query_id": "grandchild/rows", "displayed": True}])

    def run_parent(self, child_steps, answers, *, skills=(), **runner):
        """The parent's default binding of the child (None when unbound) and its reference step."""
        manifest = {"child": _skill("child", child_steps), "grandchild": self.GRANDCHILD}
        manifest.update({item["id"]: item for item in skills})
        seen, step = _run_reference(manifest, "child", answers, **runner)
        return (seen["picked"]["data"] if "picked" in seen else None), step

    def test_a_displayed_step_wins_over_an_earlier_undisplayed_one(self) -> None:
        picked, _ = self.run_parent(
            [{"id": "check", "type": "atomic", "query_id": "child/check"},
             {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True}],
            {"child/check": [{"source": "check"}], "child/read": [{"source": "read"}]},
        )
        self.assertEqual(picked, [{"source": "read"}])

    def test_without_displayed_data_the_first_step_with_data_wins(self) -> None:
        picked, _ = self.run_parent(
            [{"id": "check", "type": "atomic", "query_id": "child/check"},
             {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True}],
            {"child/check": [{"source": "check"}]},
        )
        self.assertEqual(picked, [{"source": "check"}])

    def test_a_root_step_wins_even_when_empty(self) -> None:
        picked, _ = self.run_parent(
            [{"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True},
             {"id": "root", "type": "atomic", "query_id": "child/root"}],
            {"child/read": [{"source": "read"}]},
        )
        self.assertEqual(picked, [])

    def test_a_nested_skill_never_wins_by_its_rows(self) -> None:
        steps = [
            {"id": "setup", "type": "skill", "skill": "grandchild", "displayed": True},
            {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True, "optional": True},
        ]
        for read, expected in (([{"source": "read"}], [{"source": "read"}]), ([], []), (RuntimeError("read failed"), [])):
            with self.subTest(read=read):
                picked, step = self.run_parent(steps, {"grandchild/rows": [{"source": "setup"}], "child/read": read})
                self.assertEqual(picked, expected)
                self.assertEqual(step["rows"], expected)

    def test_a_nested_skill_with_diagnostics_reads_as_its_own_default_rows(self) -> None:
        diagnosing = _skill("grandchild", [
            *self.GRANDCHILD["steps"],
            {"id": "verdict", "type": "diagnostic",
             "rules": [{"condition": "true", "diagnosis": "found", "confidence": "high"}]},
        ])
        picked, _ = self.run_parent(
            [{"id": "nested", "type": "skill", "skill": "grandchild", "displayed": True},
             {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True}],
            {"grandchild/rows": [{"source": "nested"}], "child/read": [{"source": "read"}]},
            skills=[diagnosing],
        )
        self.assertEqual(picked, [{"source": "nested"}])

    def test_an_identity_blocked_nested_skill_is_selected_without_rows(self) -> None:
        blocked = {**self.GRANDCHILD, "identity": {"policy": "required", "scope": "process"}}
        picked, _ = self.run_parent(
            [{"id": "nested", "type": "skill", "skill": "grandchild", "optional": True},
             {"id": "read", "type": "atomic", "query_id": "child/read"}],
            {"grandchild/rows": [{"source": "nested"}], "child/read": [{"source": "read"}]},
            skills=[blocked], identity_resolver=lambda _skill, _inputs: {"status": "blocked"},
        )
        self.assertEqual(picked, [])

    def test_a_displayed_iterator_with_a_failed_item_is_still_selected_without_rows(self) -> None:
        picked, _ = self.run_parent(
            [{"id": "items", "type": "atomic", "query_id": "child/items", "save_as": "items"},
             {"id": "each", "type": "iterator", "source": "items", "item_skill": "grandchild",
              "optional": True, "displayed": True},
             {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True}],
            {"child/items": [{"name": "a"}], "grandchild/rows": RuntimeError("item failed"),
             "child/read": [{"source": "read"}]},
        )
        self.assertEqual(picked, [])

    def test_selection_ignores_steps_after_the_first_required_failure(self) -> None:
        picked, step = self.run_parent(
            [{"id": "check", "type": "atomic", "query_id": "child/check"},
             {"id": "broken", "type": "atomic", "query_id": "child/broken"},
             {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True}],
            {"child/check": [{"source": "check"}], "child/broken": RuntimeError("required failed"),
             "child/read": [{"source": "read"}]},
        )
        self.assertIsNone(picked)
        self.assertEqual(step["rows"], [{"source": "check"}])

    def test_without_meaningful_data_the_last_step_holding_data_is_read(self) -> None:
        # A required step skipped by its condition holds no data, so the nested
        # reference before it is the last step that does and reads as its rows.
        picked, _ = self.run_parent(
            [{"id": "setup", "type": "skill", "skill": "grandchild"},
             {"id": "read", "type": "atomic", "query_id": "child/read", "condition": "false"}],
            {"grandchild/rows": [{"source": "setup"}]},
        )
        self.assertEqual(picked, [{"source": "setup"}])

    def test_a_step_id_read_sees_the_default_step(self) -> None:
        child = _skill("child", [
            {"id": "setup", "type": "skill", "skill": "grandchild", "displayed": True},
            {"id": "read", "type": "atomic", "query_id": "child/read", "displayed": True},
        ])
        seen, _ = _run_reference(
            {"child": child, "grandchild": self.GRANDCHILD}, "child",
            {"grandchild/rows": [{"source": "setup"}], "child/read": [{"source": "read"}]}, ref={},
        )
        self.assertEqual(seen["ref"], {"data": [{"source": "read"}]})


class GeneratedDefaultChildSelectionTest(unittest.TestCase):
    """Generated definitions read by default expose their read step, as SmartPerfetto does."""

    TOPOLOGY = [{"cpu_id": 0, "core_type": "little"}, {"cpu_id": 4, "core_type": "big"}]

    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = load_skill_script("perfetto_skill").ManifestCatalog()

    def bound(self, child_id, inputs, answers):
        seen, step = _run_reference(
            self.catalog.graph(child_id), child_id, answers, ref={"save_as": "picked", "params": inputs},
        )
        self.assertTrue(step["child"]["success"])
        return seen["picked"]["data"]

    def test_topology_backed_children_expose_their_read_step_not_topology_rows(self) -> None:
        reads = {
            "task_migration_in_range": "task_migration_in_range/migration_analysis",
            "cpu_cluster_load_in_range": "cpu_cluster_load_in_range/cluster_load",
        }
        for child_id, read_query in reads.items():
            self.assertEqual(self.catalog.load(child_id)["steps"][0]["skill"], "cpu_topology_view")
            for read, expected in (([{"source": "read"}], [{"source": "read"}]), ([], []), (RuntimeError("read failed"), [])):
                with self.subTest(child=child_id, read=read):
                    picked = self.bound(child_id, {"start_ts": 1, "end_ts": 2}, {
                        "cpu_topology_view/read_topology": self.TOPOLOGY, read_query: read,
                    })
                    self.assertEqual(picked, expected)

    def test_a_displayed_overview_wins_over_the_undisplayed_availability_check(self) -> None:
        available = [{"status": "available"}]
        picked = self.bound("suspend_wakeup_analysis", {}, {
            "suspend_wakeup_analysis/check_suspend_data": available,
            "suspend_wakeup_analysis/check_wakeup_data": available,
            "suspend_wakeup_analysis/suspend_overview": [{"source": "overview"}],
        })
        self.assertEqual(picked, [{"source": "overview"}])


class AnrPlacementDiagnosisTest(unittest.TestCase):
    """The generated anr_detail placement rule reports where the main thread ran, not why.

    anr_detail collects no cpufreq max-limit evidence, so the rule may name no
    thermal cause and leaves the frequency limit undetermined. Its share is
    defined only over fully classified Running time (unrounded unknown_running_ns).
    """

    QUADRANT = {"q1_big_running_ms": 120, "q2_little_running_ms": 2630, "unknown_running_ms": 0,
                "unknown_running_ns": 0, "q3_runnable_ms": 1750, "q4_sleeping_ms": 500, "total_ms": 5000,
                "running_pct": 55, "runnable_pct": 35, "sleeping_pct": 10}
    SCHEDULER_PRESSURE = {"direct_blocker_type": "scheduler_pressure", "confidence": "medium"}

    def setUp(self) -> None:
        manifest = SCRIPTS.parent / "references/generated/runtime/skills/anr_detail.json"
        anr = json.loads(manifest.read_text(encoding="utf-8"))
        diagnosis = next(step for step in anr["steps"] if step["id"] == "anr_event_diagnosis")
        self.rules = [rule for rule in diagnosis["rules"] if "unknown_running_ns" in rule["condition"]]
        self.all_rules = diagnosis["rules"]

    def diagnose(self, quadrant, candidates):
        from runtime.executor import SkillRunner

        parent = {
            "id": "parent", "runtime_status": "executable", "type": "composite",
            "identity": {"policy": "none"}, "inputs": [],
            "steps": [
                {"id": "quadrant", "type": "atomic", "query_id": "parent/quadrant", "save_as": "quadrant"},
                {"id": "candidates", "type": "atomic", "query_id": "parent/candidates",
                 "save_as": "direct_blocker_candidates"},
                {"id": "diagnose", "type": "diagnostic", "rules": copy.deepcopy(self.rules)},
            ],
        }
        answers = {"parent/quadrant": quadrant, "parent/candidates": candidates}
        result = SkillRunner({"skills": {"parent": parent}}, lambda query_id, **kwargs: answers[query_id]).run("parent")
        self.assertTrue(result["success"])
        return next(step for step in result["steps"] if step["step_id"] == "diagnose")["diagnostics"]

    def test_placement_renders_as_an_observation_that_defers_the_limit(self) -> None:
        self.assertEqual(len(self.rules), 1)
        [finding] = self.diagnose([self.QUADRANT], [self.SCHEDULER_PRESSURE])
        self.assertEqual(finding["diagnosis"],
                         "主线程运行时间主要在小核：大核组（超大/大/中核）120ms、小核 2630ms，同时 Runnable 等待 35%")
        self.assertEqual(len(finding["suggestions"]), 3)
        self.assertIn("是否限频以 ANR 窗口的 CPU 限频证据为准", finding["suggestions"][2])
        self.assertIn("限频与否未判定", finding["suggestions"][2])

    def test_placement_stays_silent_on_unknown_time_or_low_confidence(self) -> None:
        cases = [
            ([{**self.QUADRANT, "unknown_running_ns": 4000}], [self.SCHEDULER_PRESSURE]),
            ([{**self.QUADRANT, "unknown_running_ns": None}], [self.SCHEDULER_PRESSURE]),
            ([self.QUADRANT], [{**self.SCHEDULER_PRESSURE, "confidence": "low"}]),
            ([{**self.QUADRANT, "q1_big_running_ms": 789}], [self.SCHEDULER_PRESSURE]),
        ]
        for quadrant, candidates in cases:
            self.assertEqual(self.diagnose(quadrant, candidates), [])

    def test_no_rule_names_a_thermal_cause(self) -> None:
        texts = [text for rule in self.all_rules for text in (rule["diagnosis"], *rule.get("suggestions", []))]
        offenders = [text for text in texts
                     if re.search(r"温控|温度|过热|散热|thermal", text.replace("不是限频或温控证据", ""), re.I)]
        self.assertEqual(offenders, [])


class UnevidencedThermalWordingTest(unittest.TestCase):
    """Generated rules and texts that read no limit evidence name no thermal cause.

    A frequency drop, a frequency ratio or a low big-core frequency is an
    observation: only cpufreq max-limit evidence shows a cap, and only
    temperature or cooling-device evidence speaks to a thermal mechanism.
    """

    CAUSE = re.compile(r"温控|热控|过热|发热|高温|热节流|热降频|热限频|散热|设备温度|温度过高|温度升高|冷却后|thermal", re.I)
    DEFERRALS = ("不能据此判定限频或温控", "不判定限频或温控")
    MANIFESTS = SCRIPTS.parent / "references/generated/runtime/skills"
    SQL = SCRIPTS.parent / "references/generated/sql"

    def names_cause(self, text: str) -> bool:
        for deferral in self.DEFERRALS:
            text = text.replace(deferral, "")
        return bool(self.CAUSE.search(text))

    def rules(self, skill_id: str, step_id: str) -> list:
        """The step's frequency rules: those reading avg_freq_mhz, the inputs these cases bind."""
        skill = json.loads((self.MANIFESTS / f"{skill_id}.json").read_text(encoding="utf-8"))
        rules = next(step for step in skill["steps"] if step["id"] == step_id)["rules"]
        return [rule for rule in rules if "avg_freq_mhz" in rule["condition"]]

    def diagnose(self, rules: list, inputs: dict) -> list:
        from runtime.executor import SkillRunner

        steps = [{"id": f"stub_{name}", "type": "atomic", "query_id": f"parent/{name}", "save_as": name}
                 for name in inputs]
        parent = {"id": "parent", "runtime_status": "executable", "type": "composite",
                  "identity": {"policy": "none"}, "inputs": [],
                  "steps": [*steps, {"id": "diagnose", "type": "diagnostic", "rules": copy.deepcopy(rules)}]}
        answers = {f"parent/{name}": rows for name, rows in inputs.items()}
        result = SkillRunner({"skills": {"parent": parent}}, lambda query_id, **kwargs: answers[query_id]).run("parent")
        self.assertTrue(result["success"])
        return next(step for step in result["steps"] if step["step_id"] == "diagnose")["diagnostics"]

    def test_cpu_frequency_rules_defer_a_limit_to_its_evidence(self) -> None:
        cases = [
            (self.rules("cpu_module", "cpu_diagnosis"),
             {"freq_overview": [{"cluster": "big", "avg_freq_mhz": 1200, "max_freq_mhz": 2400},
                                {"cluster": "little", "avg_freq_mhz": 1500, "max_freq_mhz": 1800}],
              }, 2),
            (self.rules("scheduler_module", "scheduling_diagnosis"),
             {"freq_data": [{"core_type": "big", "avg_freq_mhz": 1200}]}, 1),
        ]
        for rules, inputs, deferring in cases:
            diagnostics = self.diagnose(rules, inputs)
            texts = [text for d in diagnostics for text in (d["diagnosis"], *d["suggestions"])]
            self.assertEqual([text for text in texts if self.names_cause(text)], [])
            self.assertEqual(sum("是否限频以同窗口的 CPU 限频证据" in text for text in texts), deferring)

    def test_generated_frequency_observations_name_no_thermal_cause(self) -> None:
        for path in ("gpu_analysis/root_cause_classification.sql", "gpu_frequency_analysis/query.sql",
                     "startup_slow_reasons/slow_reason_checks.sql"):
            sql = (self.SQL / path).read_text(encoding="utf-8")
            literals = [literal for literal in re.findall(r"'((?:[^']|'')*)'", re.sub(r"--[^\n]*", "", sql))
                        if re.search(r"[一-鿿]", literal)]
            self.assertTrue(literals, path)
            self.assertEqual([literal for literal in literals if self.names_cause(literal)], [], path)
        gpu = (self.SQL / "gpu_analysis/root_cause_classification.sql").read_text(encoding="utf-8")
        self.assertIn("'GPU_FREQ_DROPS'", gpu)
        self.assertNotIn("GPU_THROTTLED", gpu)


class LimitEvidencePlaceholderDefaultTest(unittest.TestCase):
    """A quoted limit-evidence path with `|` renders '' without rows, as SmartPerfetto does.

    throttle_detection and root_cause_classification still run when the limit
    step yields no rows; without the default the runtime skipped them.
    """

    MANIFESTS = SCRIPTS.parent / "references/generated/runtime/skills"

    def step(self, skill_id: str, step_id: str) -> dict:
        skill = json.loads((self.MANIFESTS / f"{skill_id}.json").read_text(encoding="utf-8"))
        return next(step for step in skill["steps"] if step["id"] == step_id)

    def test_limit_steps_are_not_result_dependencies(self) -> None:
        self.assertNotIn("limit_evidence", self.step("cpu_throttling_in_range", "throttle_detection")["result_dependencies"])
        self.assertNotIn("direct_limit_evidence",
                         self.step("thermal_throttling", "root_cause_classification")["result_dependencies"])

    def test_throttle_detection_runs_when_limit_evidence_is_empty(self) -> None:
        from runtime.executor import SkillRunner

        skill = json.loads((self.MANIFESTS / "cpu_throttling_in_range.json").read_text(encoding="utf-8"))
        topology = json.loads((self.MANIFESTS / "cpu_topology_view.json").read_text(encoding="utf-8"))
        seen = []

        def query(query_id, **kwargs):
            seen.append(query_id)
            if query_id == "cpu_throttling_in_range/throttle_detection":
                return [{"core_type": "大核", "freq_drop_pct": 0, "evidence_status": "limit_evidence_unavailable"}]
            return []

        result = SkillRunner({"skills": {"cpu_throttling_in_range": skill, "cpu_topology_view": topology}}, query).run(
            "cpu_throttling_in_range", {"start_ts": 1, "end_ts": 2})
        statuses = {step["step_id"]: step["status"] for step in result["steps"]}
        self.assertIn("cpu_throttling_in_range/throttle_detection", seen)
        self.assertEqual(statuses["throttle_detection"], "observed")


    def test_throttle_detection_reports_the_limit_status_it_read(self) -> None:
        import sqlite3

        sql = (SCRIPTS.parent / "references/generated/sql/cpu_throttling_in_range/throttle_detection.sql").read_text(
            encoding="utf-8")
        block = re.search(r"SELECT '\$\{limit_evidence\.data\[0\]\.evidence_status[^']*' AS status", sql)
        self.assertIsNotNone(block)
        cases = [(None, "limit_evidence_unavailable"), ("no_limit_episode_in_range", "no_limit_episode_in_range"),
                 ("limit_track_unavailable", "limit_track_unavailable")]
        for status, expected in cases:
            rows = [] if status is None else [{"evidence_status": status}]
            rendered = self.common.render_sql_template(block.group(0), {}, {"limit_evidence": {"data": rows}})
            self.assertEqual(sqlite3.connect(":memory:").execute(rendered).fetchone()[0], expected)
        self.assertNotIn("thermal_evidence_missing", sql)

    def setUp(self) -> None:
        self.common = load_skill_script("_common")


class ResultPathReadTest(unittest.TestCase):
    """A path read of an earlier result gates its step only where the step's condition reads that result.

    Every other such read carries a `|default`, so the step runs when the
    result has no row and binds what SmartPerfetto binds ('' in a string, NULL
    elsewhere). Bare relations (`${name}`) are not path reads and keep gating.
    """

    MANIFESTS = SCRIPTS.parent / "references/generated/runtime/skills"
    SQL = SCRIPTS.parent / "references/generated/sql"

    def test_only_a_guarding_condition_makes_a_path_read_a_dependency(self) -> None:
        undecided = []
        for path in sorted(self.MANIFESTS.glob("*.json")):
            skill = json.loads(path.read_text(encoding="utf-8"))
            aliases: dict[str, set[str]] = {}
            for step in skill.get("steps", []) or []:
                sql_path = self.SQL / f"{step.get('query_id', '')}.sql"
                sql = sql_path.read_text(encoding="utf-8") if step.get("query_id") and sql_path.is_file() else ""
                condition = step.get("condition") or ""
                for dependency in step.get("result_dependencies", []):
                    if not re.search(r"\$\{" + re.escape(dependency) + r"[.\[]", sql):
                        continue
                    names = aliases.get(dependency, {dependency})
                    if not any(re.search(r"(?<![\w.$])" + re.escape(name) + r"(?![\w$])", condition) for name in names):
                        undecided.append(f"{path.stem}/{step['id']} -> {dependency}")
                names = {str(step["id"])} | ({str(step["save_as"])} if step.get("save_as") else set())
                for name in names:
                    aliases[name] = names
        self.assertEqual(undecided, [])

    def test_scrolling_coverage_is_full_only_after_a_sufficient_comparison(self) -> None:
        import sqlite3

        # The probe maps its own coverage status to the scope the root-cause steps may claim.
        probe = (self.SQL / "scrolling_analysis/buffer_tx_coverage_probe.sql").read_text(encoding="utf-8")
        mapping = re.search(r"(CASE coverage_status.*?END) AS root_cause_evidence_scope", probe, re.S)
        self.assertIsNotNone(mapping)
        expected = {"sufficient_frame_timeline_coverage": "full_frame_timeline",
                    "partial_frame_timeline_coverage": "partial_sample",
                    "no_buffer_tx_candidate": "frame_timeline_only_unbenchmarked",
                    "no_frame_timeline_coverage": "coverage_unverified",
                    "target_process_not_found": "coverage_unverified"}
        db = sqlite3.connect(":memory:")
        self.assertEqual({status: db.execute(f"SELECT {mapping.group(1)} FROM (SELECT ? AS coverage_status)",
                                             (status,)).fetchone()[0] for status in expected}, expected)
        # A consumer reads that scope; a probe without a row leaves coverage unverified.
        for step_id in ("jank_type_stats", "batch_frame_root_cause"):
            sql = (self.SQL / f"scrolling_analysis/{step_id}.sql").read_text(encoding="utf-8")
            read = re.search(r"'\$\{buffer_tx_coverage\.data\[0\]\.root_cause_evidence_scope[^']*' as evidence_scope", sql)
            self.assertIsNotNone(read, step_id)
            for rows, scope in (([], "coverage_unverified"), ([{"root_cause_evidence_scope": "partial_sample"}], "partial_sample")):
                rendered = self.common.render_sql_template(f"SELECT {read.group(0)}", {},
                                                           {"buffer_tx_coverage": {"data": rows}})
                self.assertEqual(db.execute(rendered).fetchone()[0], scope, step_id)

    def test_scrolling_fallback_runs_when_the_coverage_probe_did_not(self) -> None:
        from runtime.executor import SkillRunner

        skill = json.loads((self.MANIFESTS / "scrolling_analysis.json").read_text(encoding="utf-8"))
        by_id = {step["id"]: step for step in skill["steps"]}
        self.assertNotIn("buffer_tx_coverage", by_id["fallback_no_frame_timeline"]["result_dependencies"])
        parent = {"id": "parent", "runtime_status": "executable", "type": "composite",
                  "identity": {"policy": "none"}, "inputs": [],
                  "steps": [{"id": "frame_timeline_check", "type": "atomic", "query_id": "parent/frame_timeline",
                             "save_as": "frame_timeline"},
                            copy.deepcopy(by_id["buffer_tx_coverage_probe"]),
                            copy.deepcopy(by_id["fallback_no_frame_timeline"])]}
        for step in parent["steps"][1:]:
            step.pop("process_scope", None)
        answers = {"parent/frame_timeline": [{"has_frame_timeline": 0}],
                   "scrolling_analysis/fallback_no_frame_timeline": [{"status": "no_frame_timeline"}]}
        result = SkillRunner({"skills": {"parent": parent}}, lambda query_id, **kwargs: answers[query_id]).run("parent")
        statuses = {step["step_id"]: step["status"] for step in result["steps"]}
        self.assertEqual(statuses, {"frame_timeline_check": "observed", "buffer_tx_coverage_probe": "skipped_condition",
                                    "fallback_no_frame_timeline": "observed"})

    def setUp(self) -> None:
        self.common = load_skill_script("_common")


class MissingEvidenceVerdictTest(unittest.TestCase):
    """Missing evidence is reported as missing, never as a negative finding."""

    MANIFESTS = SCRIPTS.parent / "references/generated/runtime/skills"
    SQL = SCRIPTS.parent / "references/generated/sql"
    WINDOWED = ("system_cpu_health", "memory_pressure", "io_load", "futex_wait_probe", "system_freeze_check",
                "top_cpu_processes")

    def setUp(self) -> None:
        self.common = load_skill_script("_common")

    def test_first_anr_window_steps_do_not_run_without_a_window(self) -> None:
        from runtime.executor import SkillRunner

        anr = json.loads((self.MANIFESTS / "anr_analysis.json").read_text(encoding="utf-8"))
        by_id = {step["id"]: step for step in anr["steps"]}
        steps = [{"id": "anr_detection", "type": "atomic", "query_id": "parent/detection", "save_as": "detection"},
                 {"id": "get_anr_context", "type": "atomic", "query_id": "parent/context", "save_as": "anr_ctx"}]
        for step_id in self.WINDOWED:
            step = copy.deepcopy(by_id[step_id])
            step.pop("process_scope", None)
            steps.append(step)
        parent = {"id": "parent", "runtime_status": "executable", "type": "composite",
                  "identity": {"policy": "none"}, "inputs": [], "steps": steps}
        answers = {"parent/detection": [{"total_anr_count": 1}], "parent/context": []}
        result = SkillRunner({"skills": {"parent": parent}}, lambda query_id, **kwargs: answers[query_id]).run("parent")
        statuses = {step["step_id"]: step["status"] for step in result["steps"]}
        self.assertEqual({step_id: statuses[step_id] for step_id in self.WINDOWED},
                         {step_id: "skipped_condition" for step_id in self.WINDOWED})

    def freeze_verdict(self, threads: dict, anr_upid=None) -> dict:
        """system_freeze_check over a 10 ms window; `threads` maps (upid, name, uid) to state segments in ms."""
        import sqlite3

        ms = 1_000_000
        sql = (self.SQL / "anr_analysis/system_freeze_check.sql").read_text(encoding="utf-8")
        rendered = self.common.render_sql_template(
            sql, {}, {"anr_ctx": {"data": [{"anr_ts": 10 * ms, "timeout_ns": 10 * ms, "upid": anr_upid}]}})
        db = sqlite3.connect(":memory:")
        db.executescript("CREATE TABLE process(upid, pid, name, uid); CREATE TABLE thread(utid, upid, tid);"
                         "CREATE TABLE thread_state(utid, ts, dur, state);")
        for (upid, name, uid), segments in threads.items():
            db.execute("INSERT INTO process VALUES (?, ?, ?, ?)", (upid, 100 + upid, name, uid))
            db.execute("INSERT INTO thread VALUES (?, ?, ?)", (upid, upid, 100 + upid))
            at = 0
            for state, dur in segments:
                db.execute("INSERT INTO thread_state VALUES (?, ?, ?, ?)", (upid, at * ms, dur * ms, state))
                at += dur
        db.row_factory = sqlite3.Row
        return dict(db.execute(rendered).fetchone())

    def test_a_window_without_evaluable_main_threads_is_undetermined(self) -> None:
        row = self.freeze_verdict({})
        self.assertEqual((row["total_apps"], row["freeze_verdict"]), (0, "undetermined"))

    def test_idle_main_threads_are_no_freeze_evidence(self) -> None:
        idle = [("Running", 0.2), ("S", 9.8)]
        starved = [("Running", 1), ("R", 7), ("S", 2)]
        server = (100, "system_server", 1000)
        apps = [(n, f"com.example.app{n}", 10100 + n) for n in range(1, 4)]
        self.assertEqual(self.freeze_verdict({server: idle, **{app: idle for app in apps}})["freeze_verdict"],
                         "app_specific")
        self.assertEqual(self.freeze_verdict({server: [("Running", 1), ("D", 8), ("S", 1)]})["freeze_verdict"],
                         "system_server_freeze")
        self.assertEqual(self.freeze_verdict({server: idle, **{app: starved for app in apps}})["freeze_verdict"],
                         "system_freeze")
        # The ANR process itself is not system-wide stall evidence.
        self.assertEqual(self.freeze_verdict({server: idle, **{app: starved for app in apps}}, anr_upid=1)
                         ["freeze_verdict"], "app_specific")

    def test_startup_evidence_matrix_reports_no_row_as_not_observed(self) -> None:
        import sqlite3

        sql = (self.SQL / "startup_analysis/startup_evidence_matrix.sql").read_text(encoding="utf-8")
        rendered = self.common.render_sql_template(sql, {}, {
            "main_thread_slices": {"data": []},
            "main_thread_file_io": {"data": [{"all_percent_of_startup": 1, "all_total_dur_ms": 10}]},
            "startup_binder": {"data": [{"all_percent_of_startup": 30}]},
        })
        rows = {item: (value, status) for item, value, status in sqlite3.connect(":memory:").execute(
            f"SELECT item, primary_value, status FROM ({rendered})")}
        self.assertEqual(rows, {
            "MainThread Hot Slice": (None, "not_observed"),
            "MainThread File IO": (1, "normal"),
            "Binder Total": (30, "needs_corroboration"),
            "Main Sync Binder": (None, "not_observed"),
            "Sched Latency": (None, "not_observed"),
        })


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


class UnobservedStepBindingTest(unittest.TestCase):
    """A declared name that a step did not observe never falls through.

    Mirrors SmartPerfetto: a step that declares ``save_as`` binds it once the
    step ran. An optional step that was skipped or whose query errored binds an
    empty result; a non-optional skip, a non-optional query error and a failed
    child Skill leave the name with no data, so neither a same-named input nor
    a caller value can be read in its place. A skip never replaces a binding an
    earlier step of the same Skill made.
    """

    PROBE_RULES = [
        {"condition": "shared === 'own'", "diagnosis": "input"},
        {"condition": "shared.data[0].source === 'caller'", "diagnosis": "caller"},
        {"condition": "shared.data[0].source === 'local'", "diagnosis": "local"},
        {"condition": "shared.data.length === 0", "diagnosis": "empty"},
    ]

    def run_child(self, child_steps, extra_skills=None, fail=()):
        from runtime.executor import SkillRunner

        seen = {}
        calls = []

        def query(query_id, **kwargs):
            calls.append(query_id)
            if query_id in fail:
                raise RuntimeError(f"{query_id} failed")
            if query_id.startswith("parent/"):
                return [{"source": "caller"}]
            if query_id == "child/probe":
                seen.update(kwargs["results"])
                return []
            if query_id.endswith("/empty"):
                return []
            return [{"source": "local"}]

        skills = {
            **(extra_skills or {}),
            "child": {
                "id": "child", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [{"name": "shared", "type": "string"}],
                "steps": [
                    *child_steps,
                    {"id": "probe", "type": "atomic", "query_id": "child/probe", "optional": True},
                    {"id": "explain", "type": "diagnostic", "rules": self.PROBE_RULES},
                ],
            },
            "parent": {
                "id": "parent", "runtime_status": "executable", "type": "composite",
                "identity": {"policy": "none"}, "inputs": [],
                "steps": [
                    {"id": "caller_step", "type": "atomic", "query_id": "parent/shared", "save_as": "shared"},
                    {"id": "call", "type": "skill", "skill": "child", "params": {"shared": "own"}, "optional": True},
                ],
            },
        }
        result = SkillRunner({"skills": skills}, query).run("parent")
        child = result["steps"][-1]["child"]
        steps = {step["step_id"]: step for step in child["steps"]}
        reads = [d["diagnosis"] for d in steps["explain"]["diagnostics"]]
        return reads, seen, steps, calls

    def assert_unobserved(self, child_steps, **kwargs):
        reads, seen, steps, calls = self.run_child(child_steps, **kwargs)
        self.assertEqual(reads, [])
        self.assertNotIn("shared", seen)
        return steps, seen

    def assert_empty(self, child_steps, **kwargs):
        reads, seen, _steps, _calls = self.run_child(child_steps, **kwargs)
        self.assertEqual(reads, ["empty"])
        self.assertEqual(seen["shared"], {"data": []})

    def test_non_optional_skip_hides_the_input_and_the_caller_value(self) -> None:
        for skipped in (
            {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared", "condition": "false"},
            {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared",
             "result_dependencies": ["nothing"]},
        ):
            with self.subTest(skipped=skipped):
                self.assert_unobserved([
                    {"id": "nothing", "type": "atomic", "query_id": "child/empty"},
                    skipped,
                ])

    def test_optional_skip_binds_an_empty_result(self) -> None:
        for skipped in (
            {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared",
             "condition": "false", "optional": True},
            {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared",
             "result_dependencies": ["nothing"], "optional": True},
        ):
            with self.subTest(skipped=skipped):
                self.assert_empty([
                    {"id": "nothing", "type": "atomic", "query_id": "child/empty"},
                    skipped,
                ])

    def test_query_error_binds_empty_when_optional_and_nothing_otherwise(self) -> None:
        step = {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared"}
        self.assert_empty([{**step, "optional": True}], fail=("child/make",))
        self.assert_unobserved([step], fail=("child/make",))

    def test_skipped_step_id_hides_the_input_and_the_caller_value(self) -> None:
        self.assert_unobserved([
            {"id": "shared", "type": "atomic", "query_id": "child/make", "condition": "false"},
        ])

    PARTIAL = {
        "partial": {
            "id": "partial", "runtime_status": "executable", "type": "composite",
            "identity": {"policy": "none"}, "inputs": [],
            "steps": [
                {"id": "rows", "type": "atomic", "query_id": "partial/rows"},
                {"id": "broken", "type": "atomic", "query_id": "partial/broken"},
            ],
        },
    }

    def test_failed_child_skill_exposes_no_rows_even_partial_ones(self) -> None:
        for ref in ({}, {"save_from": "rows"}):
            for optional in (True, False):
                with self.subTest(ref=ref, optional=optional):
                    steps, seen = self.assert_unobserved(
                        [{"id": "ref", "type": "skill", "skill": "partial", "save_as": "shared",
                          "optional": optional, **ref}],
                        extra_skills=self.PARTIAL, fail=("partial/broken",),
                    )
                    # Neither the step id nor save_as exposes the partial rows; the
                    # output record keeps them with the failed child.
                    self.assertNotIn("ref", seen)
                    self.assertEqual(steps["ref"]["rows"], [{"source": "local"}])
                    self.assertFalse(steps["ref"]["child"]["success"])

    def test_failed_child_skill_named_like_its_save_as_leaves_the_name_unbound(self) -> None:
        steps, _seen = self.assert_unobserved(
            [{"id": "shared", "type": "skill", "skill": "partial", "save_as": "shared", "optional": True}],
            extra_skills=self.PARTIAL, fail=("partial/broken",),
        )
        self.assertEqual(steps["shared"]["rows"], [{"source": "local"}])

    def test_a_skip_keeps_an_alternative_steps_binding(self) -> None:
        ran = {"id": "ran", "type": "atomic", "query_id": "child/ran", "save_as": "shared"}
        for optional in (False, True):
            gated = {"id": "gated", "type": "atomic", "query_id": "child/gated", "save_as": "shared",
                     "condition": "false", "optional": optional}
            for order in ([ran, gated], [gated, ran]):
                with self.subTest(optional=optional, first=order[0]["id"]):
                    reads, seen, _steps, _calls = self.run_child(order)
                    self.assertEqual(reads, ["local"])
                    self.assertEqual(seen["shared"], {"data": [{"source": "local"}]})

    def test_sql_reading_an_unobserved_name_is_skipped_not_rendered_with_the_input(self) -> None:
        _reads, _seen, steps, calls = self.run_child([
            {"id": "make", "type": "atomic", "query_id": "child/make", "save_as": "shared", "condition": "false"},
            {"id": "reader", "type": "atomic", "query_id": "child/reader", "result_dependencies": ["shared"]},
        ])
        self.assertEqual(steps["reader"]["status"], "skipped_empty_dependency")
        self.assertNotIn("child/reader", calls)

    def test_sql_path_with_a_default_never_renders_a_same_named_input(self) -> None:
        # Such a path is not a result dependency, so the step runs; with the name
        # unbound, the result path matches no input parameter and takes |default.
        rendered = load_skill_script("_common").render_sql_template(
            "SELECT '${shared.data[0].source|none}'", {"shared": "own"}, {},
        )
        self.assertEqual(rendered, "SELECT 'none'")


if __name__ == "__main__":
    unittest.main()
