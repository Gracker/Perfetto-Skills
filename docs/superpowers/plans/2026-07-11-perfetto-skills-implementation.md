# Perfetto Skills Public Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish `Gracker/Perfetto-Skills` as a standards-compliant, standalone Perfetto performance-analysis Agent Skill with complete SmartPerfetto Skill/workflow coverage, a portable trace processor adapter, deterministic synchronization, and verified installation.

**Architecture:** One discoverable `perfetto-performance-analysis` Skill routes to progressively disclosed workflow, knowledge, pipeline, and SQL references. A Python 3.11+ standard-library runtime executes local Perfetto queries; a PyYAML-based development exporter transforms the current SmartPerfetto YAML/strategy/pipeline truth into generated public references and a complete source catalog.

**Tech Stack:** Agent Skills open specification, Markdown/YAML/JSON, Python 3.11+, `unittest`, PyYAML 6.0.2 for development export, `skills-ref` 0.1.1, Perfetto `trace_processor_shell` v57.1, GitHub Actions, GitHub CLI.

## Global Constraints

- Repository and local directory name: `Perfetto-Skills`.
- Public Skill name and directory: `perfetto-performance-analysis`.
- License: AGPL-3.0-or-later for SmartPerfetto-derived work; preserve upstream Perfetto Apache-2.0 notices.
- Portable runtime must not require SmartPerfetto, Node.js, MCP, DataEnvelope, Provider Manager, SSE, or UI services.
- Runtime Python floor: 3.11; development/test Python supports 3.11, 3.12, and 3.13.
- `SKILL.md` uses only portable fields accepted by both official validators: `name`, `description`, `license`, and string-valued `metadata`.
- No trace processor binary is committed; every downloaded binary is selected from a lock file and SHA-256 verified.
- SmartPerfetto remains the domain source of truth; generated public references are never hand-edited.
- Every SmartPerfetto runtime Skill candidate must appear in the generated catalog with an exported, merged, or product-only disposition and a destination/reason.
- Preserve unrelated SmartPerfetto worktree changes and re-read repository status before every SmartPerfetto edit.

---

### Task 1: Public repository governance and verification entrypoint

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `LICENSE`
- Create: `NOTICE`
- Create: `SECURITY.md`
- Create: `CONTRIBUTING.md`
- Create: `AGENTS.md`
- Create: `pyproject.toml`
- Create: `uv.lock`
- Create: `tools/verify.py`
- Test: `tests/unit/test_repository_contract.py`

**Interfaces:**
- Consumes: the approved design document and SmartPerfetto AGPL license text.
- Produces: `python tools/verify.py --smartperfetto PATH`, the single local/CI verification command used by all later tasks.

- [ ] **Step 1: Write the failing repository contract test**

```python
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class RepositoryContractTest(unittest.TestCase):
    def test_required_public_files_exist(self) -> None:
        for relative in (
            "README.md", "LICENSE", "NOTICE", "SECURITY.md",
            "CONTRIBUTING.md", "AGENTS.md", "pyproject.toml",
        ):
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_license_is_agpl(self) -> None:
        self.assertIn("GNU AFFERO GENERAL PUBLIC LICENSE", (ROOT / "LICENSE").read_text())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and confirm the missing-file failure**

Run: `python3 -m unittest tests.unit.test_repository_contract -v`

Expected: FAIL naming the first missing governance file.

- [ ] **Step 3: Add governance files and project metadata**

Use the full AGPL-3.0 license text from SmartPerfetto. Set `pyproject.toml` to:

```toml
[project]
name = "perfetto-skills-dev"
version = "0.1.0"
description = "Development and validation tooling for Perfetto Skills"
requires-python = ">=3.11"
license = { text = "AGPL-3.0-or-later" }
dependencies = []

[project.optional-dependencies]
dev = ["PyYAML==6.0.2", "skills-ref==0.1.1"]

[tool.uv]
package = false
```

Run `uv lock` after writing the file and commit the resulting lock file.

Document in `AGENTS.md` that generated files are read-only, the exporter is the
source of generated references, and the only supported gate is
`python tools/verify.py --smartperfetto PATH`.

- [ ] **Step 4: Implement the verification orchestrator skeleton**

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smartperfetto", type=Path)
    args = parser.parse_args()
    run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Run the repository contract test**

Run: `python3 -m unittest tests.unit.test_repository_contract -v`

Expected: PASS.

- [ ] **Step 6: Commit the governance baseline**

```bash
git add .gitignore README.md LICENSE NOTICE SECURITY.md CONTRIBUTING.md AGENTS.md pyproject.toml uv.lock tools/verify.py tests/unit/test_repository_contract.py
git commit -m "chore: establish public repository contract"
```

### Task 2: Standards-compliant router Skill and public workflow contract

**Files:**
- Create: `skills/perfetto-performance-analysis/SKILL.md`
- Create: `skills/perfetto-performance-analysis/assets/report-schema.json`
- Create: `skills/perfetto-performance-analysis/references/workflow-index.json`
- Create: `skills/perfetto-performance-analysis/references/evidence/evidence-contract.md`
- Create: `skills/perfetto-performance-analysis/references/workflows/index.md`
- Create: `tests/unit/test_skill_contract.py`
- Modify: `tools/verify.py`

**Interfaces:**
- Consumes: open Agent Skills frontmatter rules and the workflow taxonomy in the design.
- Produces: a portable activation router, `workflow-index.json` schema, and file-based report/evidence contract used by generated references and integration tests.

- [ ] **Step 1: Write failing frontmatter and index tests**

```python
from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"


class SkillContractTest(unittest.TestCase):
    def test_frontmatter_starts_at_byte_zero(self) -> None:
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\n"))
        self.assertIn("name: perfetto-performance-analysis", text.split("---", 2)[1])

    def test_all_workflow_files_exist(self) -> None:
        index = json.loads((SKILL / "references" / "workflow-index.json").read_text())
        self.assertGreaterEqual(len(index["workflows"]), 12)
        for workflow in index["workflows"]:
            self.assertTrue((SKILL / workflow["reference"]).is_file(), workflow["id"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run and confirm missing Skill failure**

Run: `python3 -m unittest tests.unit.test_skill_contract -v`

Expected: ERROR because `SKILL.md` and the workflow index do not exist.

- [ ] **Step 3: Initialize the Skill with the official Skill Creator script**

Run:

```bash
python3 /Users/chris/.codex/skills/.system/skill-creator/scripts/init_skill.py \
  perfetto-performance-analysis \
  --path skills \
  --resources scripts,references,assets \
  --interface display_name="Perfetto Performance Analysis" \
  --interface short_description="Evidence-driven Perfetto trace analysis" \
  --interface default_prompt='Use $perfetto-performance-analysis to analyze this Perfetto trace and support every conclusion with query evidence.'
```

Expected: the Skill directory, resource directories, and
`agents/openai.yaml` are created without example files.

- [ ] **Step 4: Replace the generated template with the portable `SKILL.md` router**

The frontmatter must be exactly portable in shape:

```yaml
---
name: perfetto-performance-analysis
description: Analyze Android, Linux, and Chromium Perfetto traces with local trace_processor_shell evidence. Use for startup, scrolling or jank, input latency, ANR, CPU scheduling, memory or GC, Binder or IO, GPU or SurfaceFlinger, power or thermal, rendering-pipeline identification, trace capture guidance, and single- or multi-trace performance comparison.
license: AGPL-3.0-or-later
metadata:
  version: "0.1.0"
  source: "https://github.com/Gracker/Perfetto-Skills"
---
```

The body must require: locate the Skill root; probe before analysis; select one
workflow from the JSON index; execute deterministic SQL through the bundled
script; preserve trace/process/time identity; distinguish missing evidence from
negative evidence; verify every claim; and write the report schema.

- [ ] **Step 5: Add the workflow and report schemas**

`references/workflow-index.json` contains these stable IDs:

```json
{
  "schema_version": 1,
  "workflows": [
    {"id":"trace-overview","reference":"references/workflows/trace-overview.md"},
    {"id":"startup","reference":"references/workflows/startup.md"},
    {"id":"scrolling","reference":"references/workflows/scrolling.md"},
    {"id":"interaction","reference":"references/workflows/interaction.md"},
    {"id":"anr-blocking","reference":"references/workflows/anr-blocking.md"},
    {"id":"cpu-scheduling","reference":"references/workflows/cpu-scheduling.md"},
    {"id":"memory","reference":"references/workflows/memory.md"},
    {"id":"gpu-rendering","reference":"references/workflows/gpu-rendering.md"},
    {"id":"power-thermal","reference":"references/workflows/power-thermal.md"},
    {"id":"io-network-media","reference":"references/workflows/io-network-media.md"},
    {"id":"frameworks-games","reference":"references/workflows/frameworks-games.md"},
    {"id":"rendering-pipeline","reference":"references/workflows/rendering-pipeline.md"},
    {"id":"scene-reconstruction","reference":"references/workflows/scene-reconstruction.md"},
    {"id":"trace-comparison","reference":"references/workflows/trace-comparison.md"}
  ]
}
```

Create each referenced workflow file with the shared contract headings so the
index is valid before content migration: Purpose, Inputs, Availability gate,
Evidence sequence, Interpretation boundaries, Deep dives, Report requirements.

- [ ] **Step 6: Validate the Skill with both official validators and run unit tests**

Run:

```bash
python3 /Users/chris/.codex/skills/.system/skill-creator/scripts/quick_validate.py \
  skills/perfetto-performance-analysis
```

Expected: `Skill is valid!`.

Run: `skills-ref validate skills/perfetto-performance-analysis`

Expected: valid Skill with no schema errors.

Run: `python3 -m unittest tests.unit.test_skill_contract -v`

Expected: PASS.

- [ ] **Step 7: Wire standards validation into `tools/verify.py` and commit**

Add:

```python
run(["skills-ref", "validate", "skills/perfetto-performance-analysis"])
```

Commit:

```bash
git add skills tests/unit/test_skill_contract.py tools/verify.py
git commit -m "feat: add portable Perfetto analysis skill router"
```

### Task 3: Cross-platform trace processor bootstrap and query runtime

**Files:**
- Create: `catalog/trace-processor-lock.json`
- Create: `skills/perfetto-performance-analysis/scripts/_common.py`
- Create: `skills/perfetto-performance-analysis/scripts/bootstrap_trace_processor.py`
- Create: `skills/perfetto-performance-analysis/scripts/perfetto_query.py`
- Create: `skills/perfetto-performance-analysis/scripts/perfetto_probe.py`
- Create: `tests/unit/test_runtime.py`
- Create: `tests/unit/test_bootstrap.py`

**Interfaces:**
- Consumes: a trace path, SQL string/file, optional trace processor path, and locked official prebuilt metadata.
- Produces: `resolve_trace_processor(explicit: str | None) -> Path`, `run_query(...) -> QueryResult`, CLI JSON/CSV output, and probe JSON used by every workflow.

- [ ] **Step 1: Write failing runtime resolution and hash tests**

```python
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tests.support import load_skill_script


common = load_skill_script("_common")
bootstrap = load_skill_script("bootstrap_trace_processor")


class RuntimeTest(unittest.TestCase):
    def test_explicit_binary_wins(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / "trace_processor_shell"
            binary.write_bytes(b"binary")
            binary.chmod(0o755)
            self.assertEqual(common.resolve_trace_processor(str(binary)), binary.resolve())

    def test_hash_mismatch_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "download"
            path.write_bytes(b"wrong")
            with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                bootstrap.verify_sha256(path, hashlib.sha256(b"right").hexdigest())
```

- [ ] **Step 2: Run and confirm import failure**

Run: `python3 -m unittest tests.unit.test_runtime tests.unit.test_bootstrap -v`

Expected: FAIL because runtime scripts do not exist.

- [ ] **Step 3: Add the v57.1 lock file**

Record the five current SmartPerfetto verified hashes and official LUCI URLs for
`linux-amd64`, `linux-arm64`, `mac-amd64`, `mac-arm64`, and
`windows-amd64`. The JSON includes `perfetto_version`, `base_url`, executable
filename per platform, and SHA-256 per platform.

- [ ] **Step 4: Implement runtime resolution and subprocess execution**

`_common.py` defines:

```python
@dataclass(frozen=True)
class QueryResult:
    stdout: str
    stderr: str
    returncode: int
    command: tuple[str, ...]


def resolve_trace_processor(explicit: str | None = None) -> Path:
    candidates = [explicit, os.environ.get("PERFETTO_TRACE_PROCESSOR"), shutil.which("trace_processor_shell")]
    for candidate in candidates:
        if candidate:
            path = Path(candidate).expanduser().resolve()
            if path.is_file() and os.access(path, os.X_OK):
                return path
    cached = default_cache_binary()
    if cached.is_file() and os.access(cached, os.X_OK):
        return cached
    raise FileNotFoundError("trace_processor_shell not found; run bootstrap_trace_processor.py")
```

`run_query` invokes the trace processor in batch mode, never through a shell,
uses an explicit timeout, and returns captured streams without logging trace
contents.

- [ ] **Step 5: Implement verified download and atomic install**

`bootstrap_trace_processor.py` maps `platform.system()` and
`platform.machine()` to a lock entry, downloads to a temporary file, validates
the expected byte count when present and SHA-256 always, chmods on POSIX, and
uses `os.replace` into the cache. Unsupported platforms return exit code 2.

- [ ] **Step 6: Implement query and probe CLIs**

`perfetto_query.py` accepts exactly one of `--sql` or `--sql-file`, supports
`--format json|csv|raw`, `--timeout`, `--output`, and `--trace-processor`.
`perfetto_probe.py` runs bounded queries for trace bounds, metadata, tables,
Android version, processes, threads, and known capability families and writes a
single JSON object with `available`, `missing`, and `errors` sections.

- [ ] **Step 7: Run runtime tests and CLI help smoke tests**

Run: `python3 -m unittest tests.unit.test_runtime tests.unit.test_bootstrap -v`

Expected: PASS.

Run: `python3 skills/perfetto-performance-analysis/scripts/perfetto_query.py --help`

Expected: exit 0 and documented options.

Run: `python3 skills/perfetto-performance-analysis/scripts/perfetto_probe.py --help`

Expected: exit 0 and documented options.

- [ ] **Step 8: Commit the portable runtime**

```bash
git add catalog/trace-processor-lock.json skills/perfetto-performance-analysis/scripts tests/unit tests/support.py
git commit -m "feat: add portable trace processor runtime"
```

### Task 4: SmartPerfetto public export policy and deterministic source catalog

**Files:**
- Create in SmartPerfetto: `backend/skills/public-export.yaml`
- Create: `tools/export_from_smartperfetto.py`
- Create: `tools/validate_catalog.py`
- Create: `catalog/smartperfetto-export.json`
- Create: `tests/unit/test_exporter.py`
- Modify: `tools/verify.py`

**Interfaces:**
- Consumes: SmartPerfetto checkout plus `backend/skills/public-export.yaml`.
- Produces: deterministic `catalog/smartperfetto-export.json` and generated reference assets; exits nonzero for unknown source types, invalid policy, duplicate names, or unclassified runtime candidates.

- [ ] **Step 1: Write the failing complete-coverage test**

```python
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SMARTPERFETTO = ROOT.parent / "SmartPerfetto"


class ExporterTest(unittest.TestCase):
    def test_catalog_covers_every_runtime_candidate(self) -> None:
        subprocess.run([
            sys.executable, "tools/export_from_smartperfetto.py",
            "--source", str(SMARTPERFETTO), "--check"
        ], cwd=ROOT, check=True)
        catalog = json.loads((ROOT / "catalog/smartperfetto-export.json").read_text())
        self.assertEqual(catalog["summary"]["runtime_candidates"], len(catalog["skills"]))
        self.assertTrue(all(item["disposition"] in {"exported", "merged", "product-only"} for item in catalog["skills"]))
```

- [ ] **Step 2: Run and confirm missing exporter/policy failure**

Run: `python3 -m unittest tests.unit.test_exporter -v`

Expected: FAIL because the exporter and policy do not exist.

- [ ] **Step 3: Add the SmartPerfetto export policy**

The committed policy schema is explicit and has one entry per runtime Skill:

```yaml
version: 1
public_skill: perfetto-performance-analysis
exclude_runtime_paths:
  - backend/skills/_template
  - backend/skills/pipelines/_base.skill.yaml
skills:
  global_trace_sanity_check:
    workflow: trace-overview
    disposition: exported
  process_identity_resolver:
    workflow: trace-overview
    disposition: exported
  startup_analysis:
    workflow: startup
    disposition: exported
strategy_exports:
  include:
    - backend/strategies/*.strategy.md
    - backend/strategies/knowledge-*.template.md
  exclude:
    - backend/strategies/runtime-correctness.strategy.md
pipeline_docs:
  - docs/rendering_pipelines/*.md
```

Add `--bootstrap-policy PATH` to the exporter. It may create this file only when
the destination does not exist, seeds all 230 current names using deterministic
domain rules, and exits without generating public output. Review the resulting
mapping, then commit it. Normal export and CI never infer a workflow: they
require an exact `skills.<name>` entry, reject stale policy names, and reject
every discovered name missing from the policy.

- [ ] **Step 4: Implement deterministic discovery and normalization**

The exporter:

```python
def discover_skill_files(source: Path, policy: dict[str, object]) -> list[Path]:
    files = sorted((source / "backend" / "skills").rglob("*.skill.yaml"))
    return [path for path in files if is_runtime_candidate(path, source, policy)]


def build_catalog_entry(source: Path, path: Path, raw: dict[str, object], workflow: str) -> dict[str, object]:
    return {
        "source_path": path.relative_to(source).as_posix(),
        "source_sha256": sha256_file(path),
        "name": str(raw["name"]),
        "version": str(raw.get("version", "1.0")),
        "runtime_type": str(raw["type"]),
        "workflow": workflow,
        "disposition": "exported",
        "destination": f"references/generated/skills/{raw['name']}.md",
    }
```

Sort every list and serialize JSON with `sort_keys=True`, two-space indentation,
UTF-8, and a trailing newline. Record the SmartPerfetto commit and dirty state;
`--check` rejects dirty sources unless `--allow-dirty` is explicit.

- [ ] **Step 5: Generate the initial catalog and assert current inventory**

Run: `python3 tools/export_from_smartperfetto.py --source ../SmartPerfetto`

Expected: 235 YAML files discovered, 230 runtime candidates cataloged, 5
templates/base definitions excluded, and no unclassified paths.

- [ ] **Step 6: Add catalog validation to the root gate**

When `--smartperfetto` is present, `tools/verify.py` invokes exporter `--check`
and `tools/validate_catalog.py`. The latter checks unique name/path/destination,
existing generated destination, valid workflow IDs, hashes, and summary totals.

- [ ] **Step 7: Run SmartPerfetto's project-defined Skill gate after its policy edit**

Run from SmartPerfetto: `cd backend && npm run validate:skills`

Expected: existing Skill validation passes; the YAML export policy is outside
runtime discovery and does not change Skill execution.

- [ ] **Step 8: Commit each repository's scoped change**

SmartPerfetto:

```bash
git add backend/skills/public-export.yaml
git commit -m "docs(skills): define public Agent Skill export policy"
```

Perfetto-Skills:

```bash
git add tools/export_from_smartperfetto.py tools/validate_catalog.py catalog/smartperfetto-export.json tests/unit/test_exporter.py tools/verify.py
git commit -m "feat: catalog SmartPerfetto skill coverage"
```

### Task 5: Generate complete SQL, Skill, strategy, knowledge, and pipeline references

**Files:**
- Modify: `tools/export_from_smartperfetto.py`
- Create generated: `skills/perfetto-performance-analysis/references/generated/skills/*.md`
- Create generated: `skills/perfetto-performance-analysis/references/generated/sql/**/*.sql`
- Create generated: `skills/perfetto-performance-analysis/references/generated/strategies/*.md`
- Create generated: `skills/perfetto-performance-analysis/references/generated/knowledge/*.md`
- Create generated: `skills/perfetto-performance-analysis/references/generated/pipelines/*.md`
- Create generated: `skills/perfetto-performance-analysis/references/generated/catalog.json`
- Test: `tests/unit/test_generated_references.py`

**Interfaces:**
- Consumes: normalized YAML/Markdown sources and catalog destinations.
- Produces: agent-readable runbooks and SQL assets for every catalog entry, all marked generated with source path/hash/commit.

- [ ] **Step 1: Write failing generated-reference tests**

```python
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"


class GeneratedReferenceTest(unittest.TestCase):
    def test_every_exported_catalog_entry_has_destination(self) -> None:
        catalog = json.loads((ROOT / "catalog/smartperfetto-export.json").read_text())
        for item in catalog["skills"]:
            if item["disposition"] in {"exported", "merged"}:
                path = SKILL / item["destination"]
                self.assertTrue(path.is_file(), item["source_path"])
                self.assertIn("GENERATED FILE", path.read_text(encoding="utf-8")[:500])

    def test_generated_sql_files_are_nonempty(self) -> None:
        sql_files = list((SKILL / "references" / "generated" / "sql").rglob("*.sql"))
        self.assertGreater(len(sql_files), 100)
        self.assertTrue(all(path.read_text().strip() for path in sql_files))
```

- [ ] **Step 2: Run and confirm missing generated assets**

Run: `python3 -m unittest tests.unit.test_generated_references -v`

Expected: FAIL on the first missing destination.

- [ ] **Step 3: Render each YAML Skill as an agent-readable reference**

Each generated Skill Markdown file contains source provenance, description,
triggers, prerequisites, inputs, identity/context requirements, ordered steps,
display/evidence metadata, interpretation rules, and links to extracted SQL.
Step types are rendered with exact semantics:

```python
STEP_RENDERERS = {
    "atomic": render_atomic_step,
    "skill-ref": render_skill_reference,
    "iterator": render_iterator_step,
    "parallel": render_parallel_step,
    "conditional": render_conditional_step,
    "diagnostic": render_diagnostic_step,
    "ai_decision": render_ai_decision_step,
    "ai_summary": render_ai_summary_step,
    "pipeline": render_pipeline_step,
}
```

Unknown step types terminate export. SQL filenames are derived from Skill name
and step ID, not array position, and collisions terminate export.

- [ ] **Step 4: Export strategy and knowledge methodology without product runtime text**

Copy selected strategy sections into generated references with provenance. Strip
only frontmatter fields and injected product instructions that require
`submit_plan`, `invoke_skill`, SmartPerfetto artifact APIs, session state, or UI
actions; retain phase recipes, evidence boundaries, schema/table guidance,
misdiagnosis guards, and report checks. The exporter records every stripped
section in `references/generated/catalog.json` with a reason.

- [ ] **Step 5: Export all rendering pipelines and docs**

For each real `pipeline_definition`, generate one Markdown reference containing
detection required/scoring/exclusion signals, teaching summary/diagram, thread
roles, key slices, common issues, recommended evidence, and source doc link.
Mark auto-pin instructions as optional SmartPerfetto UI metadata. Export the 31
real pipeline definitions and all policy-selected rendering pipeline documents.

- [ ] **Step 6: Generate twice and assert byte-for-byte determinism**

Run:

```bash
python3 tools/export_from_smartperfetto.py --source ../SmartPerfetto
git diff --exit-code
python3 tools/export_from_smartperfetto.py --source ../SmartPerfetto
git diff --exit-code
```

Expected: both post-generation diffs are empty after adding the intended first
generation result to the index.

- [ ] **Step 7: Run generated-reference tests and commit**

Run: `python3 -m unittest tests.unit.test_generated_references -v`

Expected: PASS with every catalog destination present.

Commit:

```bash
git add tools/export_from_smartperfetto.py catalog skills/perfetto-performance-analysis/references/generated tests/unit/test_generated_references.py
git commit -m "feat: export complete SmartPerfetto evidence catalog"
```

### Task 6: Curate the public workflow runbooks and evidence boundaries

**Files:**
- Modify: `skills/perfetto-performance-analysis/references/workflows/*.md`
- Create: `skills/perfetto-performance-analysis/references/evidence/identity.md`
- Create: `skills/perfetto-performance-analysis/references/evidence/missing-data.md`
- Create: `skills/perfetto-performance-analysis/references/evidence/claim-verification.md`
- Create: `skills/perfetto-performance-analysis/references/knowledge/data-sources.md`
- Create: `skills/perfetto-performance-analysis/references/knowledge/thread-state.md`
- Create: `skills/perfetto-performance-analysis/references/knowledge/rendering-pipeline.md`
- Create: `skills/perfetto-performance-analysis/references/knowledge/startup-root-causes.md`
- Create: `skills/perfetto-performance-analysis/references/knowledge/thermal-power.md`
- Test: `tests/unit/test_workflow_coverage.py`

**Interfaces:**
- Consumes: generated Skill/SQL/strategy references and the workflow index.
- Produces: standalone phase recipes that an arbitrary compatible agent can execute with only local files and the query runtime.

- [ ] **Step 1: Write a failing workflow contract validator**

```python
from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills" / "perfetto-performance-analysis"
REQUIRED = (
    "## Purpose", "## Inputs", "## Availability gate",
    "## Evidence sequence", "## Interpretation boundaries",
    "## Deep dives", "## Report requirements",
)


class WorkflowCoverageTest(unittest.TestCase):
    def test_every_workflow_has_complete_contract(self) -> None:
        index = json.loads((SKILL / "references" / "workflow-index.json").read_text())
        for item in index["workflows"]:
            text = (SKILL / item["reference"]).read_text()
            for heading in REQUIRED:
                self.assertIn(heading, text, f"{item['id']}: {heading}")
            self.assertIn("references/generated/", text, item["id"])
```

- [ ] **Step 2: Run and identify incomplete workflow contracts**

Run: `python3 -m unittest tests.unit.test_workflow_coverage -v`

Expected: FAIL until all workflow contracts and generated-reference links are
filled with concrete content.

- [ ] **Step 3: Write the overview, identity, and evidence foundation**

Require trace bounds and data-source probing first. Define stable identity keys
for trace path/hash, process upid/pid/name, thread utid/tid/name, timestamp,
duration, and trace side. State that absent rows are negative evidence only when
the required table/module/signal and requested time/process scope are confirmed.

- [ ] **Step 4: Write the lifecycle and interaction workflows**

Complete startup, scrolling, interaction, ANR/blocking, scene reconstruction,
and trace comparison. Link every phase to generated Skills/SQL. Preserve
startup type boundaries, self-time attribution, frame-production versus
presentation separation, hidden jank, blocked-function limits, and the rule to
analyze traces independently before delta attribution.

- [ ] **Step 5: Write the resource and platform workflows**

Complete CPU/scheduling, memory, GPU/rendering, power/thermal,
IO/network/media, frameworks/games, and rendering-pipeline workflows. Preserve
version/vendor gating and distinguish correlation, mechanism evidence, and
proven root cause.

- [ ] **Step 6: Validate coverage and forbidden product dependencies**

Extend the test to reject these runtime-only tokens in curated public files:

```python
FORBIDDEN = ("submit_plan", "invoke_skill(", "DataEnvelope", "artifactStore", "SSE", "Provider Manager")
```

Generated provenance files may mention their original field names, but router
and curated workflows may not require them.

Run: `python3 -m unittest tests.unit.test_workflow_coverage -v`

Expected: PASS for all 14 workflows.

- [ ] **Step 7: Commit the complete public methodology**

```bash
git add skills/perfetto-performance-analysis/references tests/unit/test_workflow_coverage.py
git commit -m "feat: migrate Perfetto analysis workflows"
```

### Task 7: Client installer and optional Codex metadata

**Files:**
- Create: `tools/install.py`
- Modify: `skills/perfetto-performance-analysis/agents/openai.yaml`
- Create: `tests/unit/test_installer.py`
- Modify: `README.md`

**Interfaces:**
- Consumes: canonical `skills/perfetto-performance-analysis` directory.
- Produces: deterministic copy installation for `codex`, `claude-code`, `opencode`, or `--destination PATH`; never mutates existing installs unless `--force`.

- [ ] **Step 1: Write failing install-path and overwrite tests**

```python
from pathlib import Path
import tempfile
import unittest

from tools.install import install_skill


class InstallerTest(unittest.TestCase):
    def test_installs_canonical_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp) / ".agents" / "skills"
            installed = install_skill(destination, force=False)
            self.assertEqual(installed, destination / "perfetto-performance-analysis")
            self.assertTrue((installed / "SKILL.md").is_file())

    def test_refuses_overwrite_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            destination = Path(tmp)
            install_skill(destination, force=False)
            with self.assertRaises(FileExistsError):
                install_skill(destination, force=False)
```

- [ ] **Step 2: Run and confirm missing installer failure**

Run: `python3 -m unittest tests.unit.test_installer -v`

Expected: FAIL because `tools.install` does not exist.

- [ ] **Step 3: Implement path resolution and safe copy**

Use these client defaults relative to `--home` or the real home:

```python
CLIENT_PATHS = {
    "codex": Path(".agents/skills"),
    "claude-code": Path(".claude/skills"),
    "opencode": Path(".opencode/skills"),
}
```

Copy to a temporary sibling directory, validate `SKILL.md`, then atomically
rename. With `--force`, move the old install to a backup until the new rename
succeeds, then remove the backup.

- [ ] **Step 4: Validate optional Codex UI metadata**

The Skill-local `agents/openai.yaml` contains only `interface.display_name`,
`interface.short_description`, and `interface.default_prompt`. The prompt must
mention `$perfetto-performance-analysis`. Do not declare MCP dependencies,
because the portable Skill runs through local scripts.

- [ ] **Step 5: Run installer tests and isolated discovery smoke tests**

Run: `python3 -m unittest tests.unit.test_installer -v`

Expected: PASS.

Run three installs under a temporary home and confirm each installed
`SKILL.md` has the same SHA-256 as the canonical file.

- [ ] **Step 6: Commit installer and public instructions**

```bash
git add tools/install.py skills/perfetto-performance-analysis/agents/openai.yaml README.md tests/unit/test_installer.py
git commit -m "feat: support cross-client skill installation"
```

### Task 8: Real trace integration, pipeline, and comparison verification

**Files:**
- Create: `tests/fixtures/README.md`
- Create: `tests/integration/test_real_trace.py`
- Create: `tests/integration/test_comparison.py`
- Create: `tests/integration/test_pipeline.py`
- Create: `tests/support.py`
- Modify: `tools/verify.py`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: SmartPerfetto test trace paths supplied through `SMARTPERFETTO_TEST_TRACES`, local/bootstrapped trace processor, exported SQL, and public workflows.
- Produces: evidence that the standalone runtime executes representative startup, scrolling, pipeline, and comparison paths without SmartPerfetto services.

- [ ] **Step 1: Write opt-in integration tests with explicit fixture contract**

```python
import os
from pathlib import Path
import unittest


TRACE_ROOT = Path(os.environ["SMARTPERFETTO_TEST_TRACES"]) if "SMARTPERFETTO_TEST_TRACES" in os.environ else None


@unittest.skipUnless(TRACE_ROOT and TRACE_ROOT.is_dir(), "SMARTPERFETTO_TEST_TRACES not configured")
class RealTraceTest(unittest.TestCase):
    def test_startup_probe_and_query(self) -> None:
        trace = TRACE_ROOT / "launch_light.pftrace"
        self.assertTrue(trace.is_file())
        result = run_public_query(trace, "trace-overview")
        self.assertEqual(result["status"], "ok")
        self.assertGreater(result["trace_end_ns"], result["trace_start_ns"])
```

Use equivalent explicit tests for standard AOSP scrolling, Flutter TextureView
pipeline detection, and two startup traces in comparison order.

- [ ] **Step 2: Run without fixtures and confirm honest skips**

Run: `python3 -m unittest discover -s tests/integration -p 'test_*.py' -v`

Expected: tests SKIP with `SMARTPERFETTO_TEST_TRACES not configured`, not PASS by
mocking trace data.

- [ ] **Step 3: Run against the six current SmartPerfetto traces**

Run:

```bash
SMARTPERFETTO_TEST_TRACES=../SmartPerfetto/test-traces \
PERFETTO_TRACE_PROCESSOR=../SmartPerfetto/backend/bin/trace_processor_shell \
python3 -m unittest discover -s tests/integration -p 'test_*.py' -v
```

If the committed binary is not at that path, resolve the actual current
SmartPerfetto prebuilt from repository scripts and pass it explicitly. Do not
download an unverified fallback.

Expected: startup, scrolling, pipeline, and comparison tests PASS on real
traces. Any unavailable signal must produce a typed unavailable result rather
than a fabricated empty success.

- [ ] **Step 4: Wire real trace mode into verification**

`tools/verify.py` always runs unit tests and standards validation. When
`--smartperfetto` is supplied, it locates `test-traces`, resolves the pinned
prebuilt, sets the integration environment, and requires all integration tests.

- [ ] **Step 5: Commit integration coverage without large trace binaries**

```bash
git add tests/fixtures/README.md tests/integration tests/support.py tools/verify.py .gitignore
git commit -m "test: verify standalone analysis on real traces"
```

### Task 9: SmartPerfetto documentation and synchronization contract

**Files:**
- Modify in SmartPerfetto: `docs/reference/skill-system.md`
- Modify in SmartPerfetto: `docs/reference/skill-system.en.md`
- Modify in SmartPerfetto: `.claude/rules/skills.md`
- Create in SmartPerfetto: `scripts/verify-public-skill-export.sh`
- Modify in SmartPerfetto: `package.json`
- Create: `docs/architecture.md`
- Create: `docs/compatibility.md`
- Create: `docs/migration-coverage.md`

**Interfaces:**
- Consumes: public repo exporter/catalog and current SmartPerfetto Skill rules.
- Produces: documented single-source relationship and a SmartPerfetto-supported verification command that detects public export drift.

- [ ] **Step 1: Add a failing SmartPerfetto export verification script**

The script resolves `PERFETTO_SKILLS_DIR` or the sibling
`../Perfetto-Skills`, validates it is a Git checkout, and runs:

```bash
python3 "$PERFETTO_SKILLS_DIR/tools/export_from_smartperfetto.py" --source "$SMARTPERFETTO_DIR" --check
```

It exits 2 with an actionable message when the public checkout is absent and 1
on drift. Add root script `verify:public-skills` that invokes it.

- [ ] **Step 2: Replace the stale “no migration needed” documentation**

Explain that YAML Skills remain the deterministic SmartPerfetto runtime truth,
while `Gracker/Perfetto-Skills` is the generated/curated portable Agent Skill
projection. Document what is exported, what remains product-only, how source
hashes work, and the drift command. Update both languages consistently.

- [ ] **Step 3: Document the public architecture and exact migration coverage**

`docs/migration-coverage.md` is generated from the catalog summary and groups
all 230 candidates by runtime type, workflow, and disposition. It must not
hardcode counts outside the generated section. `docs/compatibility.md` records
Python, trace processor, client paths, platform prebuilt matrix, and unsupported
cloud-only agents without filesystem/terminal access.

- [ ] **Step 4: Run current-project-defined SmartPerfetto gates**

Run from SmartPerfetto:

```bash
cd backend && npm run validate:skills
cd .. && npm run verify:public-skills
```

Before a PR or push, run from the SmartPerfetto root:

```bash
npm run verify:pr
```

Expected: all configured gates PASS. If `verify:pr` exposes unrelated external
state, report it precisely and do not hide or bypass it.

- [ ] **Step 5: Commit SmartPerfetto and public documentation separately**

SmartPerfetto:

```bash
git add docs/reference/skill-system.md docs/reference/skill-system.en.md .claude/rules/skills.md scripts/verify-public-skill-export.sh package.json
git commit -m "docs(skills): link portable Perfetto Skills export"
```

Perfetto-Skills:

```bash
git add docs/architecture.md docs/compatibility.md docs/migration-coverage.md
git commit -m "docs: explain architecture and migration coverage"
```

### Task 10: CI, release packaging, and supply-chain metadata

**Files:**
- Create: `.github/workflows/verify.yml`
- Create: `.github/workflows/release.yml`
- Create: `tools/build_release.py`
- Create: `tests/unit/test_release.py`
- Modify: `README.md`
- Modify: `SECURITY.md`

**Interfaces:**
- Consumes: canonical Skill tree, source catalog, tests, and a checked-out pinned SmartPerfetto commit.
- Produces: CI verification and release archives/checksums that contain exactly one installable Skill directory plus provenance metadata.

- [ ] **Step 1: Write failing deterministic release test**

```python
from pathlib import Path
import tempfile
import unittest
import zipfile

from tools.build_release import build_release


class ReleaseTest(unittest.TestCase):
    def test_archive_contains_installable_skill(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            archive, checksum = build_release(Path(tmp), "0.1.0")
            self.assertTrue(checksum.is_file())
            with zipfile.ZipFile(archive) as bundle:
                names = set(bundle.namelist())
            self.assertIn("perfetto-performance-analysis/SKILL.md", names)
            self.assertFalse(any(name.endswith("trace_processor_shell") for name in names))
```

- [ ] **Step 2: Run and confirm missing release builder failure**

Run: `python3 -m unittest tests.unit.test_release -v`

Expected: FAIL because `tools.build_release` does not exist.

- [ ] **Step 3: Implement reproducible archive and checksum generation**

Normalize archive timestamps, permissions, path ordering, and UTF-8 names.
Include the canonical Skill directory, `LICENSE`, `NOTICE`, source commit file,
and generated catalog. Produce `.zip`, `.tar.gz`, and `SHA256SUMS`.

- [ ] **Step 4: Add CI verification**

The verification workflow checks out Perfetto-Skills and SmartPerfetto at the
catalog's pinned source commit, runs `uv sync --extra dev` with Python
3.11/3.12/3.13,
runs `python tools/verify.py --smartperfetto ../SmartPerfetto`, and uploads test
logs only on failure. Do not log trace contents.

- [ ] **Step 5: Add tag release workflow**

On `v*` tags, rerun verification, call `tools/build_release.py`, verify archive
contents, and upload archives plus checksums to the GitHub release. Use GitHub's
provided token and least-privilege `contents: write` only in the release job.

- [ ] **Step 6: Run release tests and commit**

Run: `python3 -m unittest tests.unit.test_release -v`

Expected: PASS and two identical builds have identical SHA-256 hashes.

Commit:

```bash
git add .github tools/build_release.py tests/unit/test_release.py README.md SECURITY.md
git commit -m "ci: verify and package Perfetto Skills releases"
```

### Task 11: Simplification, independent review, complete verification, and GitHub publication

**Files:**
- Modify only files touched by findings that are confirmed in review.

**Interfaces:**
- Consumes: complete local repositories and configured validation commands.
- Produces: reviewed commits, public `Gracker/Perfetto-Skills`, pushed default branch, and fresh-clone proof.

- [ ] **Step 1: Run the configured simplification path**

Check for the current environment `/simplify`, a repository-defined simplifier,
then `code-simplifier` on PATH. If none is available, perform an explicit manual
review of only changed code and run `git diff --check` in both repositories.
Do not format or touch unrelated files.

- [ ] **Step 2: Run a read-only independent architecture and security review**

Give the reviewer the approved design, current diffs, catalog summary, runtime
download boundary, generated-file contract, and full verification results.
Require findings to identify path/line, impact, and evidence. Revise only
confirmed issues, then rerun the affected gates.

- [ ] **Step 3: Run complete local verification**

Perfetto-Skills:

```bash
python3 tools/verify.py --smartperfetto ../SmartPerfetto
git diff --check
git status --short --branch
```

SmartPerfetto:

```bash
npm run verify:public-skills
npm run verify:pr
git diff --check
git status --short --branch
```

Expected: all tests/gates PASS and both worktrees contain only intentional
committed changes.

- [ ] **Step 4: Create and push the public GitHub repository**

Run from Perfetto-Skills:

```bash
gh repo create Gracker/Perfetto-Skills --public --source=. --remote=origin --push --description "Portable Agent Skills for evidence-driven Perfetto performance analysis"
```

Verify:

```bash
gh repo view Gracker/Perfetto-Skills --json nameWithOwner,visibility,url,defaultBranchRef
git ls-remote --heads origin main
```

Expected: visibility `PUBLIC`, default branch `main`, and remote main equals
local HEAD.

- [ ] **Step 5: Push the SmartPerfetto source-policy/documentation commits**

Confirm the root does not point at a local-only Perfetto submodule commit, then:

```bash
git submodule status perfetto
git push origin main
```

Expected: SmartPerfetto `origin/main` contains the public export policy and docs,
and the submodule commit is reachable from its configured remote.

- [ ] **Step 6: Verify from a fresh clone**

In a temporary directory:

```bash
gh repo clone Gracker/Perfetto-Skills
cd Perfetto-Skills
python3 -m venv .venv
uv sync --extra dev
.venv/bin/python tools/verify.py --smartperfetto /absolute/path/to/SmartPerfetto
.venv/bin/python tools/install.py --client codex --home "$PWD/.smoke-home"
skills-ref validate skills/perfetto-performance-analysis
```

Expected: clone, dependency install, verification, installation, and Skill
validation all PASS without reading files from the original local checkout.

- [ ] **Step 7: Record final evidence and tag the first release**

Create `v0.1.0` only after the public main branch and fresh-clone verification
pass:

```bash
git tag -a v0.1.0 -m "Perfetto Skills v0.1.0"
git push origin v0.1.0
gh release view v0.1.0 --json isDraft,isPrerelease,url,assets
```

Expected: non-draft, non-prerelease release with installable archives and
`SHA256SUMS` after the release workflow completes.
