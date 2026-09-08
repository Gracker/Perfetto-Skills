import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from tools import export_from_smartperfetto as exporter


ROOT = Path(__file__).resolve().parents[2]
EXPORTER = ROOT / "tools" / "export_from_smartperfetto.py"
CATALOG = ROOT / "catalog" / "smartperfetto-export.json"
MIGRATION_DOC = ROOT / "docs" / "migration-coverage.md"


class ExpandSqlFragmentsTest(unittest.TestCase):
    """A fragment may end with a `-- MARKER_END` comment.

    Joining fragments with a trailing "," puts the CTE separator inside that
    comment, so SQLite ignores it and the next CTE is left syntactically
    unseparated. Keep every separator on its own line.
    """

    def _write(self, root: Path, name: str, body: str) -> None:
        target = root / "backend" / "skills" / "fragments" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body, encoding="utf-8")

    def test_separator_survives_a_fragment_ending_in_a_comment(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            self._write(
                root,
                "marker.sql",
                "first_cte AS (\n  SELECT 1 AS a\n)\n-- MARKER_END",
            )
            expanded, _ = exporter.expand_sql_fragments(
                "WITH\nsecond_cte AS (\n  SELECT 2 AS b\n)\nSELECT * FROM second_cte",
                ["fragments/marker.sql"],
                root,
            )

        self.assertNotIn("-- MARKER_END,", expanded)
        for line in expanded.splitlines():
            stripped = line.strip()
            if stripped.startswith("--"):
                self.assertFalse(
                    stripped.endswith(","),
                    f"CTE separator swallowed by a comment: {line!r}",
                )
        self.assertIn("second_cte AS (", expanded)


class ExporterTest(unittest.TestCase):
    def setUp(self) -> None:
        self.assertTrue(EXPORTER.is_file(), "tools/export_from_smartperfetto.py")

    def load_catalog(self) -> dict[str, object]:
        self.assertTrue(CATALOG.is_file(), "catalog/smartperfetto-export.json")
        return json.loads(CATALOG.read_text(encoding="utf-8"))

    def test_catalog_covers_every_runtime_candidate(self) -> None:
        catalog = self.load_catalog()
        summary = catalog["summary"]
        self.assertEqual(
            summary["skill_yaml_files"],
            summary["runtime_candidates"] + summary["excluded_skill_definitions"],
        )
        self.assertEqual(catalog["summary"]["runtime_candidates"], len(catalog["skills"]))
        self.assertTrue(
            all(
                item["disposition"] in {"exported", "merged", "product-only"}
                for item in catalog["skills"]
            )
        )

    def test_repository_identity_is_stable_across_checkout_protocols(self) -> None:
        expected = "https://github.com/Gracker/SmartPerfetto"
        for remote in (
            "git@github.com:Gracker/SmartPerfetto.git",
            "ssh://git@github.com/Gracker/SmartPerfetto.git",
            "https://github.com/Gracker/SmartPerfetto",
            "https://github.com/Gracker/SmartPerfetto.git",
        ):
            with self.subTest(remote=remote):
                self.assertEqual(exporter.canonical_repository(remote), expected)

    def test_catalog_has_unique_sources_names_and_destinations(self) -> None:
        catalog = self.load_catalog()
        self.assertIn("official_perfetto", catalog)
        self.assertIn("runtime_perfetto", catalog)
        for key in ("source_path", "name"):
            values = [item[key] for item in catalog["skills"]]
            self.assertEqual(len(values), len(set(values)), key)
        destinations = [
            item["destination"]
            for item in catalog["skills"]
            if item["disposition"] != "product-only"
        ]
        self.assertEqual(len(destinations), len(set(destinations)))

    def test_strategies_and_pipeline_docs_are_classified(self) -> None:
        catalog = self.load_catalog()
        self.assertGreaterEqual(len(catalog["strategies"]), 60)
        self.assertEqual(
            len(catalog["strategies"]), catalog["summary"]["strategy_sources"]
        )
        pipeline_docs = catalog["pipeline_docs"]
        self.assertEqual(len(pipeline_docs), 14)
        self.assertEqual(
            [item["source_path"].split("/")[-1].split("_")[0] for item in pipeline_docs],
            [f"S{index:02d}" for index in range(1, 15)],
        )
        self.assertTrue(
            all(item["disposition"] == "exported" for item in pipeline_docs)
        )

    def test_bootstrap_classifier_preserves_domain_boundaries(self) -> None:
        cases = {
            "android_kernel_wakelock_summary": "power-thermal",
            "wakelock_tracking": "power-thermal",
            "block_io_analysis": "io-network-media",
            "frame_blocking_calls": "scrolling",
            "rendering_pipeline_detection": "rendering-pipeline",
            "pipeline_key_slices_overlay": "rendering-pipeline",
            "android_dvfs_counter_stats": "cpu-scheduling",
            "launcher_module": "startup",
            "art_module": "memory",
        }
        for name, expected in cases.items():
            with self.subTest(name=name):
                self.assertEqual(
                    exporter.classify_skill(name, {"type": "atomic"}), expected
                )

    def test_perfetto_source_lock_separates_official_skill_from_runtime(self) -> None:
        official_commit = "a" * 40
        official_tree = "b" * 40
        runtime_revision = "c" * 40
        runtime_tree = "d" * 40
        official_skill = b"official tagged Skill"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "SmartPerfetto"
            (source / "perfetto").mkdir(parents=True)
            data = source / "backend/data"
            data.mkdir(parents=True)
            (data / "perfettoStdlibSymbols.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            (data / "perfettoSqlDocs.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            skill_root = root / "skill"
            lock_path = skill_root / "references/trace-processor-lock.json"
            lock_path.parent.mkdir(parents=True)
            lock_path.write_text(
                json.dumps(
                    {
                        "schema_version": 2,
                        "revision": runtime_revision,
                        "reported_version": "v57.2",
                        "rpc_api_version": 14,
                        "platforms": {"test": {"path": "unused", "sha256": "e" * 64}},
                    }
                ),
                encoding="utf-8",
            )
            catalog = {
                "official_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "tag": "v57.2",
                    "commit": official_commit,
                    "rpc_api_version": 14,
                    "stdlib_tree": official_tree,
                    "official_skill_reference": "ai/skills/perfetto/SKILL-template.md",
                    "official_skill_role": "gap_check_only",
                },
                "runtime_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "reported_version": "v57.2",
                    "revision": runtime_revision,
                    "rpc_api_version": 14,
                    "stdlib_tree": runtime_tree,
                },
            }

            def git_identity(_repository: Path, *arguments: str) -> str:
                revision = arguments[-1]
                values = {
                    "v57.2^{}": official_commit,
                    "v57.2:src/trace_processor/perfetto_sql/stdlib": official_tree,
                    f"{runtime_revision}^{{commit}}": runtime_revision,
                    f"{runtime_revision}:src/trace_processor/perfetto_sql/stdlib": runtime_tree,
                }
                return values[revision]

            with mock.patch.object(exporter, "git_output", side_effect=git_identity), mock.patch.object(
                exporter, "git_file_bytes", return_value=official_skill
            ):
                result = exporter.build_perfetto_source_lock(
                    source, catalog, skill_root=skill_root
                )

        self.assertEqual(result["official_reference"]["commit"], official_commit)
        self.assertEqual(result["official_reference"]["stdlib_tree"], official_tree)
        self.assertEqual(result["runtime"]["revision"], runtime_revision)
        self.assertEqual(result["runtime"]["stdlib_tree"], runtime_tree)
        self.assertNotIn("release", result)
        self.assertEqual(
            result["official_reference"]["skill"]["sha256"],
            exporter.hashlib.sha256(official_skill).hexdigest(),
        )

    def test_perfetto_source_lock_rejects_generated_assets_from_another_revision(self) -> None:
        runtime_revision = "c" * 40
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "SmartPerfetto"
            (source / "perfetto").mkdir(parents=True)
            data = source / "backend/data"
            data.mkdir(parents=True)
            (data / "perfettoStdlibSymbols.json").write_text(
                json.dumps({"generatedFrom": "f" * 40}), encoding="utf-8"
            )
            (data / "perfettoSqlDocs.json").write_text(
                json.dumps({"generatedFrom": runtime_revision}), encoding="utf-8"
            )
            skill_root = root / "skill"
            lock_path = skill_root / "references/trace-processor-lock.json"
            lock_path.parent.mkdir(parents=True)
            lock_path.write_text(
                json.dumps(
                    {
                        "schema_version": 2,
                        "revision": runtime_revision,
                        "reported_version": "v57.2",
                        "rpc_api_version": 14,
                        "platforms": {"test": {"path": "unused", "sha256": "e" * 64}},
                    }
                ),
                encoding="utf-8",
            )
            catalog = {
                "official_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "tag": "v57.2",
                    "commit": "a" * 40,
                    "rpc_api_version": 14,
                    "stdlib_tree": "b" * 40,
                    "official_skill_reference": "ai/skills/perfetto/SKILL-template.md",
                    "official_skill_role": "gap_check_only",
                },
                "runtime_perfetto": {
                    "repository": "https://github.com/google/perfetto",
                    "reported_version": "v57.2",
                    "revision": runtime_revision,
                    "rpc_api_version": 14,
                    "stdlib_tree": "d" * 40,
                },
            }

            def git_identity(_repository: Path, *arguments: str) -> str:
                revision = arguments[-1]
                values = {
                    "v57.2^{}": "a" * 40,
                    "v57.2:src/trace_processor/perfetto_sql/stdlib": "b" * 40,
                    f"{runtime_revision}^{{commit}}": runtime_revision,
                    f"{runtime_revision}:src/trace_processor/perfetto_sql/stdlib": "d" * 40,
                }
                return values[revision]

            with mock.patch.object(exporter, "git_output", side_effect=git_identity), mock.patch.object(
                exporter, "git_file_bytes", return_value=b"official tagged Skill"
            ):
                with self.assertRaisesRegex(
                    exporter.ExportError,
                    "perfettoStdlibSymbols.json.*does not match runtime revision",
                ):
                    exporter.build_perfetto_source_lock(
                        source, catalog, skill_root=skill_root
                    )

    def test_migration_coverage_is_rendered_from_catalog(self) -> None:
        catalog = self.load_catalog()
        expected = exporter.render_migration_coverage(catalog)
        self.assertEqual(MIGRATION_DOC.read_text(encoding="utf-8"), expected)
        self.assertIn(catalog["source"]["commit"], expected)
        for count in (
            catalog["summary"]["runtime_candidates"],
            catalog["summary"]["strategy_sources"],
            catalog["summary"]["pipeline_docs"],
        ):
            self.assertIn(str(count), expected)


class ProcessScopeExportTest(unittest.TestCase):
    """Export native declarations from a tiny source tree, never the live pin."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name).resolve()
        self.source = root / "SmartPerfetto"
        self.generated = root / "output"
        self.skill_root = root / "public-skill"
        self.commit = "a" * 40
        symbols = self.source / "backend/data/perfettoStdlibSymbols.json"
        symbols.parent.mkdir(parents=True)
        symbols.write_text("{}", encoding="utf-8")
        self.fragment = self.source / "backend/skills/fragments/effective_target_processes.sql"
        self.fragment.parent.mkdir(parents=True)
        self.fragment.write_text(
            "effective_target_processes AS (SELECT * FROM process "
            "WHERE ${__process_scope.upid} IS NULL OR upid = ${__process_scope.upid})",
            encoding="utf-8",
        )
        self.identity = {
            "policy": "verify_if_present", "scope": "process",
            "aliases": ["package", "process_name"],
        }
        self.scope = {"role": "target", "binding": "effective_target_processes"}
        self.catalog = {
            "source": {"commit": self.commit}, "skills": [],
            "strategies": [], "sql_fragments": [], "vendor_overrides": [],
        }

    def add_skill(self, name, body):
        relative = f"backend/skills/{name}.skill.yaml"
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        # JSON is YAML; this fixture needs no string templating of source SQL.
        path.write_text(json.dumps({
            "name": name, "version": "1.0", "type": "atomic",
            "identity": self.identity,
            "inputs": [{"name": "package", "type": "string", "required": False}],
            **body,
        }), encoding="utf-8")
        self.catalog["skills"].append({
            "name": name, "source_path": relative,
            "source_sha256": exporter.sha256_file(path), "disposition": "exported",
        })

    def export(self):
        source_lock = {"runtime": {
            "revision": "b" * 40, "reported_version": "fixture",
            "stdlib_tree": "c" * 40,
        }}
        # Pin/fixture discovery is outside this test. Actual normalization,
        # fragment expansion, setup detection, hashes and manifests are real.
        with mock.patch.object(exporter, "load_fixture_manifest", return_value=({"fixtures": []}, {})), mock.patch.object(
            exporter, "build_perfetto_source_lock", return_value=source_lock,
        ), mock.patch.object(exporter, "git_output", return_value=""):
            exporter.build_runtime_assets(
                self.source, self.catalog, self.generated, skill_root=self.skill_root,
            )

    def queries(self, skill_id):
        shard = self.generated / f"runtime/queries/{skill_id}.json"
        return {entry["id"]: entry for entry in json.loads(shard.read_text())["queries"]}

    def assert_scope_query(self, entry):
        self.assertEqual(entry["template"].get("runtime_bindings"), ["__process_scope.upid"])
        self.assertEqual(entry["template"].get("name_parameters"), ["package"])
        self.assertEqual(entry["template"]["parameters"], ["package"])
        self.assertEqual(entry["template"]["result_dependencies"], [])
        self.assertEqual(entry.get("process_scope"), self.scope)
        self.assertEqual(entry.get("identity"), self.identity)
        self.assertEqual(entry["template"]["fragments"], [{
            "order": 0,
            "source_path": "backend/skills/fragments/effective_target_processes.sql",
            "source_sha256": exporter.sha256_file(self.fragment),
        }])
        sql_path = self.generated / entry["path"]
        sql = sql_path.read_text(encoding="utf-8")
        self.assertIn("effective_target_processes AS (", sql)
        self.assertIn("${__process_scope.upid}", sql)
        self.assertEqual(entry["sha256"], exporter.sha256_file(sql_path))
        self.assertEqual(entry["source"]["commit"], self.commit)
        self.assertFalse(entry["validation"]["execution_verified"])
        self.assertFalse(entry["validation"]["semantic_verified"])

    def test_root_fragment_and_scope_declaration_survive_atomic_export(self) -> None:
        self.add_skill("scoped", {
            "process_scope": self.scope,
            "sql_fragments": ["fragments/effective_target_processes.sql"],
            "sql": "SELECT * FROM effective_target_processes WHERE name = '${package}'",
            "exact_sql": {
                "sql": "SELECT 'EXACT_BRANCH_MUST_NOT_REPLACE_BASE' AS value",
                "process_scope": self.scope,
                "sql_fragments": ["fragments/effective_target_processes.sql"],
            },
        })
        self.export()
        query = self.queries("scoped")["scoped/root"]
        self.assert_scope_query(query)
        self.assertEqual(query["path"], "sql/scoped/query.sql")
        skill = json.loads((self.generated / "runtime/skills/scoped.json").read_text())
        self.assertEqual(skill.get("process_scope"), self.scope)
        self.assertEqual(skill["identity"], self.identity)
        self.assertEqual(query["compatibility"].get("exact_scope", {}).get("status"), "unsupported")
        self.assertNotIn(
            "EXACT_BRANCH_MUST_NOT_REPLACE_BASE",
            (self.generated / query["path"]).read_text(encoding="utf-8"),
        )

    def test_composite_fragments_and_setup_dependencies_keep_runtime_binding_metadata(self) -> None:
        self.add_skill("composite", {
            "type": "composite",
            "steps": [
                {"id": "setup", "type": "atomic", "sql": "CREATE VIEW prepared AS SELECT 1 AS value;"},
                {
                    "id": "scoped", "type": "atomic", "process_scope": self.scope,
                    "sql_fragments": ["fragments/effective_target_processes.sql"],
                    "sql": "SELECT p.* FROM effective_target_processes p JOIN prepared "
                    "WHERE p.name = '${package}'",
                },
            ],
        })
        self.export()
        queries = self.queries("composite")
        query = queries["composite/scoped"]
        self.assert_scope_query(query)
        self.assertEqual(query["sql_dependencies"]["setup_queries"], ["composite/setup"])
        self.assertEqual(query["sql_dependencies"]["requires"], ["prepared"])
        self.assertEqual(queries["composite/setup"]["template"].get("runtime_bindings"), [])
        manifest = json.loads((self.generated / "runtime/skills/composite.json").read_text())
        self.assertEqual(manifest["steps"][1].get("process_scope"), self.scope)

    def test_identity_metadata_fallback_exports_its_actual_role_and_exact_unavailable(self) -> None:
        declaration = {
            "role": "identity_metadata",
            "exact_unavailable": "No FrameTimeline evidence is available for this UPID; BufferTX names cannot establish exact frame rate or jank.",
        }
        self.add_skill("fallback", {
            "type": "composite", "steps": [
                {"id": "coverage", "type": "atomic", "save_as": "coverage",
                 "sql": "SELECT 'not_found' AS target_process_status"},
                {"id": "fallback_no_frame_timeline", "type": "atomic", "process_scope": declaration,
                 "sql": "SELECT CASE WHEN ${__process_scope.upid} IS NOT NULL "
                 "THEN 'unavailable_exact_upid' ELSE '${coverage.data[0].target_process_status}' END AS status, "
                 "'${package}' AS requested_package"},
            ],
        })
        self.export()
        query = self.queries("fallback")["fallback/fallback_no_frame_timeline"]
        self.assertEqual(query.get("process_scope"), declaration)
        self.assertNotIn("binding", query["process_scope"])
        self.assertEqual(query["template"]["runtime_bindings"], ["__process_scope.upid"])
        self.assertEqual(query["template"]["result_dependencies"], ["coverage"])
        self.assertEqual(query["template"]["parameters"], ["package"])
        self.assertFalse(query["validation"]["semantic_verified"])
        manifest = json.loads((self.generated / "runtime/skills/fallback.json").read_text())
        self.assertEqual(manifest["steps"][1].get("process_scope"), declaration)

    def test_context_declarations_without_reserved_tokens_are_validated_too(self) -> None:
        for declaration in (
            {"role": "unknown_role"},
            {"role": "global_context", "binding": "native_upid"},
            {"role": "identity_metadata", "exact_unavailable": ""},
            {"role": "peer_context", "context_fields": {"target": ["value"]}},
        ):
            with self.subTest(declaration=declaration):
                self.catalog["skills"].clear()
                self.add_skill("invalid", {"process_scope": declaration, "sql": "SELECT 1 AS value"})
                with self.assertRaises(exporter.ExportError):
                    self.export()

    def test_reserved_token_defaults_are_not_exportable_even_with_a_valid_target_declaration(self) -> None:
        for default in ("99", "null", ""):
            with self.subTest(default=default):
                self.catalog["skills"].clear()
                self.add_skill("invalid", {
                    "process_scope": self.scope, "sql_fragments": ["fragments/effective_target_processes.sql"],
                    "sql": "SELECT ${__process_scope.upid|" + default + "} AS invalid_upid "
                    "FROM effective_target_processes WHERE name = '${package}'",
                })
                with self.assertRaises(exporter.ExportError):
                    self.export()


if __name__ == "__main__":
    unittest.main()
