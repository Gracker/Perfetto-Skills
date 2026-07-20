import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
REQUIRED = (
    "## Purpose",
    "## Inputs",
    "## Availability gate",
    "## Evidence sequence",
    "## Interpretation boundaries",
    "## Deep dives",
    "## Report requirements",
)
FORBIDDEN = (
    "submit_plan",
    "invoke_skill(",
    "DataEnvelope",
    "artifactStore",
    "SSE",
    "Provider Manager",
)
FOUNDATION_FILES = (
    "references/evidence/identity.md",
    "references/evidence/missing-data.md",
    "references/evidence/claim-verification.md",
    "references/knowledge/data-sources.md",
    "references/knowledge/thread-state.md",
    "references/knowledge/rendering-pipeline.md",
    "references/knowledge/startup-root-causes.md",
    "references/knowledge/thermal-power.md",
)


class WorkflowCoverageTest(unittest.TestCase):
    def test_every_workflow_has_complete_contract_and_generated_links(self) -> None:
        index = json.loads(
            (SKILL / "references" / "workflow-index.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(index["workflows"]), 14)
        for item in index["workflows"]:
            path = SKILL / item["reference"]
            text = path.read_text(encoding="utf-8")
            for heading in REQUIRED:
                self.assertIn(heading, text, f"{item['id']}: {heading}")
            links = re.findall(r"\[[^]]+\]\(([^)]+)\)", text)
            generated_links = [link for link in links if "../generated/" in link]
            self.assertTrue(generated_links, item["id"])
            for link in links:
                if link.startswith(("http://", "https://", "#")):
                    continue
                self.assertTrue((path.parent / link).resolve().is_file(), f"{path}: {link}")

    def test_curated_files_have_no_product_runtime_dependencies(self) -> None:
        paths = [SKILL / "SKILL.md"]
        paths.extend((SKILL / "references" / "workflows").glob("*.md"))
        paths.extend(SKILL / relative for relative in FOUNDATION_FILES)
        for path in paths:
            self.assertTrue(path.is_file(), path)
            text = path.read_text(encoding="utf-8")
            for token in FORBIDDEN:
                self.assertNotIn(token, text, f"{path}: {token}")

    def test_evidence_foundation_defines_stable_keys_and_negative_evidence(self) -> None:
        identity = (SKILL / "references/evidence/identity.md").read_text(
            encoding="utf-8"
        )
        for key in ("trace_sha256", "upid", "pid", "utid", "tid", "ts", "dur", "trace_side"):
            self.assertIn(f"`{key}`", identity)
        missing = (SKILL / "references/evidence/missing-data.md").read_text(
            encoding="utf-8"
        )
        for phrase in ("required table", "requested scope", "negative evidence"):
            self.assertIn(phrase, missing.lower())

    def test_comparison_workflow_uses_portable_files(self) -> None:
        comparison = (SKILL / "references/workflows/trace-comparison.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("perfetto_compare.py", comparison)
        self.assertIn("comparison-input-schema.json", comparison)
        self.assertNotIn("snapshot_id", comparison)

    def test_trace_overview_has_bounded_secondary_sweep(self) -> None:
        overview = (SKILL / "references/workflows/trace-overview.md").read_text(
            encoding="utf-8"
        )
        for phrase in (
            "at most three",
            "already repeat evidence",
            "unresolved alternatives",
            "specific bounded question",
        ):
            self.assertIn(phrase, overview)


if __name__ == "__main__":
    unittest.main()
