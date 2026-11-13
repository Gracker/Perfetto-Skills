from copy import deepcopy
import hashlib
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

import yaml

from tools import pipeline_teaching
from tools.pipeline_teaching import (
    DESTINATION,
    SOURCE_PATH,
    PipelineTeachingError,
    load_pipeline_teaching,
)


class PipelineTeachingTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.source = Path(temporary.name) / "source"
        self.directory = self.source / "backend/skills/pipelines"
        self.directory.mkdir(parents=True)
        self.catalog = {
            "version": "3.0",
            "rendering_types": {
                "S01_OVERVIEW": self.card("overview", "Evidence overview"),
                "S02_STANDARD": self.card("concrete", "Window rendering"),
                "S16_CHROMIUM_BROWSER": self.card("concrete", "Browser output"),
            },
            "default": {"pipeline_id": "TEST_WINDOW", "rendering_type_id": "S02_STANDARD"},
            "pipelines": {
                "TEST_WINDOW": {"file": "window.skill.yaml", "teaching_type_id": "S02_STANDARD"},
                "TEST_BROWSER": {"file": "browser.skill.yaml", "teaching_type_id": "S16_CHROMIUM_BROWSER"},
            },
        }
        self.entries = []
        self.definitions = {}
        for pipeline_id, mapping in self.catalog["pipelines"].items():
            reference = f"skills/pipelines/index.yaml#rendering_types.{mapping['teaching_type_id']}"
            aliases = ["DrawGL*", "WebViewFunctor::drawVk"]
            definition = {
                "name": pipeline_id.lower(),
                "type": "pipeline_definition",
                "meta": {"pipeline_id": pipeline_id, "doc_path": reference},
                "teaching": {"source": reference},
                "detection": {
                    "required_signals": [{"slice_patterns": aliases}],
                    "scoring_signals": [{"signal": "draw", "slice_patterns": aliases, "weight": 25}],
                },
            }
            self.definitions[pipeline_id] = definition
            self.write_definition(pipeline_id, definition)
            self.entries.append({
                "name": definition["name"],
                "runtime_type": "pipeline_definition",
                "disposition": "exported",
                "source_path": f"backend/skills/pipelines/{mapping['file']}",
            })
        self.write_catalog(self.catalog)

    @staticmethod
    def card(kind: str, title: str) -> dict:
        return {
            "kind": kind,
            "teaching": {
                "title": title,
                "summary": "Measure production, consumption and presentation separately.",
                "mermaidBlocks": ["flowchart LR\n Producer --> Consumer"],
                "threadRoles": [{"thread": "RenderThread", "responsibility": "Submit work", "traceTag": "DrawFrame"}],
                "keySlices": ["queueBuffer", "WebViewFunctor::drawVk"],
            },
        }

    def write_catalog(self, catalog: dict) -> None:
        (self.source / SOURCE_PATH).write_text(yaml.safe_dump(catalog), encoding="utf-8")

    def write_definition(self, pipeline_id: str, definition: dict) -> None:
        filename = self.catalog["pipelines"][pipeline_id]["file"]
        (self.directory / filename).write_text(yaml.safe_dump(definition), encoding="utf-8")

    def load(self):
        result = load_pipeline_teaching(self.source, self.entries)
        self.assertIsNotNone(result)
        return result

    def test_no_exported_pipeline_requires_no_catalog_or_source_checkout(self) -> None:
        missing = self.source / "does-not-exist"
        self.assertIsNone(load_pipeline_teaching(missing, []))
        self.assertIsNone(load_pipeline_teaching(missing, [
            {"runtime_type": "atomic", "disposition": "exported"},
            {"runtime_type": "pipeline_definition", "disposition": "product-only"},
        ]))

    def test_descriptor_binds_the_complete_catalog_and_only_exported_pipelines(self) -> None:
        teaching = load_pipeline_teaching(self.source, self.entries[:1])
        self.assertEqual(teaching.descriptor(), {
            "source_path": SOURCE_PATH,
            "source_sha256": hashlib.sha256((self.source / SOURCE_PATH).read_bytes()).hexdigest(),
            "destination": DESTINATION,
            "rendering_types": ["S01_OVERVIEW", "S02_STANDARD", "S16_CHROMIUM_BROWSER"],
            "pipelines": {"TEST_WINDOW": "S02_STANDARD"},
        })
        self.assertEqual(self.load().descriptor()["pipelines"]["TEST_BROWSER"], "S16_CHROMIUM_BROWSER")

    def test_projection_rewrites_nested_references_and_sql_without_altering_detection(self) -> None:
        teaching = self.load()
        value = {
            "source": "skills/pipelines/index.yaml#rendering_types.S02_STANDARD",
            "catalog": "backend/skills/pipelines/index.yaml",
            "nested": [
                "Read `backend/skills/pipelines/index.yaml#rendering_types.S01_OVERVIEW`.",
                "SELECT 'skills/pipelines/index.yaml#rendering_types.S16_CHROMIUM_BROWSER' AS doc_path",
                True, None, 25,
            ],
            "detection": self.definitions["TEST_WINDOW"]["detection"],
        }
        before = deepcopy(value)
        projected = teaching.project(value)
        self.assertEqual(projected["source"], f"{DESTINATION}#s02_standard")
        self.assertEqual(projected["catalog"], DESTINATION)
        self.assertEqual(projected["nested"], [
            f"Read `{DESTINATION}#s01_overview`.",
            f"SELECT '{DESTINATION}#s16_chromium_browser' AS doc_path",
            True, None, 25,
        ])
        self.assertEqual(projected["detection"], value["detection"])
        projected["detection"]["required_signals"][0]["slice_patterns"].append("caller")
        self.assertEqual(value, before)
        self.assertEqual(teaching.project(projected["source"]), projected["source"])

    def test_render_is_self_contained_with_stable_anchors_and_source_hash(self) -> None:
        teaching = self.load()
        expected_hash = teaching.descriptor()["source_sha256"]
        rendered = teaching.render()
        self.assertTrue(rendered.startswith("GENERATED FILE - DO NOT EDIT.\n"))
        self.assertIn(f"Source: {SOURCE_PATH}\n", rendered)
        self.assertIn(f"Source SHA-256: {expected_hash}\n", rendered)
        for type_id, definition in self.catalog["rendering_types"].items():
            self.assertIn(f'<a id="{type_id.lower()}"></a>', rendered)
            self.assertIn(definition["teaching"]["title"], rendered)
            self.assertIn(definition["teaching"]["summary"], rendered)
        self.assertIn("```mermaid\nflowchart LR", rendered)
        self.assertIn("| RenderThread | Submit work | DrawFrame |", rendered)
        self.assertIn("queueBuffer", rendered)
        self.assertNotIn("Source commit", rendered)
        self.assertNotIn(str(self.source), rendered)
        self.assertTrue(all(line == line.rstrip() for line in rendered.splitlines()))

        # The installed projection needs no source repository after import.
        shutil.rmtree(self.source)
        self.assertEqual(teaching.render(), rendered)
        self.assertEqual(teaching.project("skills/pipelines/index.yaml"), DESTINATION)

    def test_descriptor_and_card_mutations_do_not_change_a_loaded_snapshot(self) -> None:
        teaching = self.load()
        rendered = teaching.render()
        descriptor = teaching.descriptor()
        descriptor["rendering_types"].clear()
        descriptor["pipelines"]["TEST_WINDOW"] = "caller"
        self.catalog["rendering_types"]["S02_STANDARD"]["teaching"]["title"] = "Modified later"
        self.write_catalog(self.catalog)
        self.assertEqual(teaching.render(), rendered)
        self.assertEqual(teaching.descriptor()["pipelines"]["TEST_WINDOW"], "S02_STANDARD")
        self.assertEqual(len(teaching.descriptor()["rendering_types"]), 3)

    def test_unknown_or_unsafe_product_references_fail_instead_of_leaving_a_dependency(self) -> None:
        teaching = self.load()
        for reference in [
            "skills/pipelines/index.yaml#rendering_types.UNKNOWN",
            "backend/skills/pipelines/index.yaml#rendering_types.s02_standard",
            "skills/pipelines/index.yaml#other",
            "skills/pipelines/index.yaml#rendering_types.",
            "../backend/skills/pipelines/index.yaml",
            "/tmp/skills/pipelines/index.yaml",
            "skills/pipelines/index.yaml/extra",
            "skills/pipelines/index.yaml.bak",
        ]:
            with self.subTest(reference=reference), self.assertRaises(PipelineTeachingError):
                teaching.project({"reference": [reference]})

    def test_legacy_catalogs_and_document_fields_are_rejected(self) -> None:
        for field in ("source", "documents", "document"):
            catalog = deepcopy(self.catalog)
            catalog[field] = []
            self.write_catalog(catalog)
            with self.subTest(field=field), self.assertRaises(PipelineTeachingError):
                self.load()
        catalog = deepcopy(self.catalog)
        catalog["version"] = "2.0"
        self.write_catalog(catalog)
        with self.assertRaises(PipelineTeachingError):
            self.load()
        catalog = deepcopy(self.catalog)
        catalog["rendering_types"]["S02_STANDARD"]["document"] = "unpublished.md"
        self.write_catalog(catalog)
        with self.assertRaises(PipelineTeachingError):
            self.load()

    def test_invalid_card_fields_and_roles_are_rejected(self) -> None:
        cases = [
            ("title", ""), ("summary", 42), ("mermaidBlocks", "diagram"),
            ("mermaidBlocks", [None]), ("keySlices", [""]), ("threadRoles", None),
            ("threadRoles", [None]),
            ("threadRoles", [{"thread": "main"}]),
            ("threadRoles", [{"thread": "main", "responsibility": ""}]),
            ("threadRoles", [{"thread": "main", "responsibility": "draw", "traceTag": None}]),
            ("threadRoles", [{"thread": "main", "responsibility": "draw", "extra": "unsupported"}]),
        ]
        for field, value in cases:
            catalog = deepcopy(self.catalog)
            catalog["rendering_types"]["S02_STANDARD"]["teaching"][field] = value
            self.write_catalog(catalog)
            with self.subTest(field=field, value=value), self.assertRaises(PipelineTeachingError):
                self.load()

    def test_card_ids_kinds_and_type_references_are_validated(self) -> None:
        for mutate in [
            lambda catalog: catalog["rendering_types"].update({"../BAD": self.card("concrete", "Bad")}),
            lambda catalog: catalog["rendering_types"]["S02_STANDARD"].update({"kind": []}),
            lambda catalog: catalog["pipelines"]["TEST_WINDOW"].update({"teaching_type_id": "UNKNOWN"}),
            lambda catalog: catalog["pipelines"]["TEST_WINDOW"].update({"related_rendering_type_ids": ["UNKNOWN"]}),
            lambda catalog: catalog["default"].update({"rendering_type_id": "UNKNOWN"}),
        ]:
            catalog = deepcopy(self.catalog)
            mutate(catalog)
            self.write_catalog(catalog)
            with self.assertRaises(PipelineTeachingError):
                self.load()

    def test_pipeline_metadata_and_teaching_must_bind_the_declared_type(self) -> None:
        original = self.definitions["TEST_WINDOW"]
        for field in ("meta", "teaching"):
            definition = deepcopy(original)
            key = "doc_path" if field == "meta" else "source"
            definition[field][key] = "skills/pipelines/index.yaml#rendering_types.S01_OVERVIEW"
            self.write_definition("TEST_WINDOW", definition)
            with self.subTest(field=field), self.assertRaises(PipelineTeachingError):
                self.load()
        definition = deepcopy(original)
        definition["meta"]["doc_path"] = "backend/skills/pipelines/index.yaml#rendering_types.S02_STANDARD"
        self.write_definition("TEST_WINDOW", definition)
        self.assertIsNotNone(self.load())

    def test_pipeline_paths_and_duplicate_exports_are_rejected(self) -> None:
        for filename in ("../outside.skill.yaml", "/tmp/window.skill.yaml", "dir\\window.skill.yaml", "./window.skill.yaml"):
            catalog = deepcopy(self.catalog)
            catalog["pipelines"]["TEST_WINDOW"]["file"] = filename
            self.write_catalog(catalog)
            with self.subTest(filename=filename), self.assertRaises(PipelineTeachingError):
                self.load()
        self.write_catalog(self.catalog)
        for relative in ("../outside.skill.yaml", "/tmp/window.skill.yaml"):
            entries = deepcopy(self.entries)
            entries[0]["source_path"] = relative
            with self.assertRaises(PipelineTeachingError):
                load_pipeline_teaching(self.source, entries)
        with self.assertRaises(PipelineTeachingError):
            load_pipeline_teaching(self.source, self.entries + self.entries[:1])

    def test_catalog_filename_mismatch_and_symlinked_definitions_are_rejected(self) -> None:
        catalog = deepcopy(self.catalog)
        catalog["pipelines"]["TEST_WINDOW"]["file"] = "other.skill.yaml"
        self.write_catalog(catalog)
        with self.assertRaises(PipelineTeachingError):
            self.load()
        self.write_catalog(self.catalog)
        target = self.directory / "window.skill.yaml"
        replacement = self.source / "replacement.yaml"
        target.rename(replacement)
        target.symlink_to(replacement)
        with self.assertRaises(PipelineTeachingError):
            self.load()

    def test_an_article_path_is_rejected_before_any_attempt_to_read_it(self) -> None:
        entries = deepcopy(self.entries)
        entries[0]["source_path"] = "docs/rendering_pipelines/unpublished.md"
        with mock.patch.object(pipeline_teaching, "_read_yaml", wraps=pipeline_teaching._read_yaml) as reader:
            with self.assertRaises(PipelineTeachingError):
                load_pipeline_teaching(self.source, entries)
        self.assertEqual(reader.call_args_list, [mock.call(self.source.resolve(), SOURCE_PATH)])


if __name__ == "__main__":
    unittest.main()
