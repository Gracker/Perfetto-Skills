# Independent Upstream Sync and SQL Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate SmartPerfetto import, Google official Skill gap checking, PerfettoSQL substrate synchronization, and local SQL development into explicit pinned workflows that preserve local fixes.

**Architecture:** Machine-readable locks describe each upstream. A separate committed immutable SmartPerfetto base tree plus a path/hash manifest preserves reconstructable upstream content. Local overlays carry expected base hashes and full replacement content; the compiler materializes final generated output into a different tree. Sync tools write temporary reports by default and update locks/snapshots only with `--apply`.

**Tech Stack:** Python 3.11 standard library plus development PyYAML, JSON, SHA-256, Git, PerfettoSQL, Python `unittest`, GitHub Actions.

## Global Constraints

- Official Perfetto Skill remains gap-check-only and is never a runtime dependency.
- Google's canonical tag, peeled commit, RPC API, stdlib tree, and binary hashes must agree.
- SmartPerfetto sync never overwrites a local overlay silently.
- Local SQL changes require project-owned real-trace red-green assertions.
- Sync tools are dry-run by default and do not mutate upstream checkouts.
- Generated runtime files are written only by importer/compiler tools.

---

### Task 1: Introduce upstream locks and generated-base manifest

**Files:**
- Create: `upstreams/smartperfetto.lock.json`
- Create: `upstreams/google-perfetto.lock.json`
- Create: `upstreams/snapshots/smartperfetto/generated-base.json`
- Create: `upstreams/snapshots/smartperfetto/base/` (complete imported base)
- Create: `tools/upstream_locks.py`
- Create: `tests/unit/test_upstream_locks.py`

**Interfaces:**
- Produces: typed lock loaders, SHA validation, repository identity validation, and `build_generated_base(root: Path) -> dict`.
- Consumes: current catalog, current runtime `perfetto-source-lock.json`, and generated tree.

- [ ] **Step 1: Write failing lock tests**

Require immutable 40-hex commits, HTTPS GitHub repository identities, v57.2
tag/commit/RPC/tree values, official Skill `gap_check_only`, unique generated
paths, every manifest hash matching the separate base tree, and a zero-overlay
compile matching current generated output.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_upstream_locks`

Expected: FAIL because locks/module do not exist.

- [ ] **Step 3: Implement lock validation and base manifest generation**

The base manifest maps each base-tree relative path to `{sha256, source_kind,
source_commit}`. Sort all keys and use deterministic JSON serialization. The
base tree stores the complete imported bytes and is never the compiler output.

- [ ] **Step 4: Seed locks from current verified v0.2 state**

Copy only verified immutable values from `catalog/smartperfetto-export.json`, `runtime/perfetto-source-lock.json`, and `trace-processor-lock.json`. Do not infer unknown values.

- [ ] **Step 5: Run lock tests**

Expected: PASS and no generated tree drift.

---

### Task 2: Split SmartPerfetto import from local compilation

**Files:**
- Modify: `tools/export_from_smartperfetto.py`
- Create: `tools/sync_smartperfetto.py`
- Create: `tools/compile_skill.py`
- Create: `tests/unit/test_smartperfetto_sync.py`
- Create: `tests/unit/test_compile_skill.py`

**Interfaces:**
- Produces: `import_to_directory(source, output)`, `compare_import(base_manifest, imported_root)`, `load_overlays(root)`, and `compile_tree(imported_root, overlays, output)`.
- Consumes: SmartPerfetto lock, public export policy, current base manifest, and local overlays.

- [ ] **Step 1: Write failing dry-run/import tests**

Tests require a clean temporary import, added/removed/changed report, no repository mutation without `--apply`, and rejection when source repository/commit differs from the requested lock.

- [ ] **Step 2: Write failing compiler tests**

Use a three-file miniature generated tree. Assert non-overridden files remain byte-identical, matching-hash overlay replaces one file, stale base hash fails, output is deterministic, and source trees remain unchanged.

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
uv run python -m unittest \
  tests.unit.test_smartperfetto_sync \
  tests.unit.test_compile_skill
```

Expected: FAIL because sync/compiler entry points do not exist.

- [ ] **Step 4: Refactor exporter output targeting**

Make the exporter accept an explicit output root and catalog path without changing current default behavior. It must not read or write local overlays.

- [ ] **Step 5: Implement dry-run SmartPerfetto sync**

Import into a temporary directory, compare against the committed base manifest, validate overlay base hashes, and write JSON/Markdown reports under an explicit output directory. `--apply` atomically replaces the upstream base outputs and lock only after validation.

- [ ] **Step 6: Implement deterministic local compiler**

Compiler inputs are the separate committed immutable base tree, base manifest,
`src/` native assets, and overlays. It validates expected hashes, writes a
temporary final tree, then checks or atomically applies it. It never reads the
current final generated tree as base and never mutates the base tree.

- [ ] **Step 7: Run sync/compiler tests and current export check**

Expected: tests pass; compiling with zero overlays reproduces the current generated tree exactly.

---

### Task 3: Add first-class Skill, Strategy, and SQL overlays

**Files:**
- Create: `src/README.md`
- Create: `src/overrides/schema.json`
- Create: `src/overrides/sql/.gitkeep`
- Create: `src/overrides/skills/.gitkeep`
- Create: `src/overrides/strategies/.gitkeep`
- Create: `tools/overlays.py`
- Create: `tests/unit/test_overlays.py`

**Interfaces:**
- Produces: `Overlay` records with target path, kind, base hash, replacement path/hash, reason, regression IDs, and upstream-candidate state.
- Consumes: JSON overlay descriptors and replacement files.

- [ ] **Step 1: Write failing overlay validation tests**

Reject unsafe paths, unknown kinds, missing replacement, replacement hash mismatch, missing reason, empty regression IDs for SQL, duplicate targets, and invalid upstream-candidate state.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_overlays`

- [ ] **Step 3: Implement schema and loader**

Allowed kinds are `sql`, `skill`, and `strategy`; upstream candidate states are `propose`, `local_only`, and `accepted_upstream`. SQL overlays require at least one owned fixture assertion ID.

- [ ] **Step 4: Document local modification workflow**

`src/README.md` gives exact red-green commands, explains why generated files are not edited, and shows a complete descriptor example whose test creates and hashes a temporary base/replacement pair.

- [ ] **Step 5: Run overlay and compiler tests**

Expected: PASS.

---

### Task 4: Implement Google official Skill gap synchronization

**Files:**
- Create: `tools/sync_official_skill.py`
- Create: `upstreams/snapshots/google-perfetto/official-skill.json`
- Create: `upstreams/reports/official-skill-gap.json`
- Create: `tests/unit/test_official_skill_sync.py`

**Interfaces:**
- Produces: `inventory_official_skill(perfetto: Path, revision: str) -> dict` and `build_gap_report(previous, current, local_contract) -> dict`.
- Consumes: pinned official repository/tag/commit and local workflow/runtime contract inventory.

- [ ] **Step 1: Write failing inventory/gap tests**

Tests require deterministic path/hash/license inventory, tag-to-commit verification, changed/added/removed classification, and gap outcomes limited to `adopted`, `already_covered`, `not_applicable`, and `pending_review`.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_official_skill_sync`

- [ ] **Step 3: Implement read-only official inventory**

Read files through `git show "${revision}:${path}"` so the checkout working tree is never mutated. Inventory `ai/skills/perfetto/` and retain Apache provenance.

- [ ] **Step 4: Implement structured gap report**

Compare router/workflow/reference concepts with local workflow IDs and documented safety contracts. Never auto-mark a new official behavior adopted.

- [ ] **Step 5: Generate the v57.2 baseline**

Run against canonical Google Perfetto v57.2, verify its peeled commit, and commit the inventory and fully classified gap report.

- [ ] **Step 6: Run official sync tests and dry-run**

Expected: clean v57.2 baseline produces no unreviewed drift.

---

### Task 5: Implement PerfettoSQL stdlib synchronization and drift report

**Files:**
- Create: `tools/sync_perfetto_stdlib.py`
- Create: `upstreams/snapshots/google-perfetto/stdlib-index.json`
- Create: `upstreams/reports/perfetto-stdlib-drift.json`
- Create: `tests/unit/test_perfetto_stdlib_sync.py`

**Interfaces:**
- Produces: `build_stdlib_index(perfetto: Path, revision: str) -> dict` and `compare_stdlib(old, new) -> dict`.
- Consumes: official `src/trace_processor/perfetto_sql/stdlib/**/*.sql` through `git ls-tree`/`git show`.

- [ ] **Step 1: Write failing index/drift tests**

Miniature fixtures verify module path discovery, CREATE PERFETTO TABLE/VIEW/FUNCTION/MACRO symbol extraction, file hashes, tree ID, added/removed/changed modules, and deterministic output.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_perfetto_stdlib_sync`

- [ ] **Step 3: Implement canonical release checks**

Reject tag/commit mismatch, stdlib tree mismatch, RPC mismatch, or binary lock version mismatch before indexing.

- [ ] **Step 4: Implement index and drift generation**

Record module, source path, source hash, exported symbols, and best-effort doc comments. Unknown SQL constructs remain explicit parse warnings and block lock promotion until reviewed.

- [ ] **Step 5: Generate and verify v57.2 baseline**

Expected: committed index tree equals the lock tree and current generated query dependencies resolve against it.

---

### Task 6: Strengthen all-query and local-SQL execution validation

**Files:**
- Create: `tools/validate_all_queries.py`
- Create: `tests/unit/test_all_query_validation.py`
- Modify: `tests/integration/test_fixture_manifest.py`
- Create: `tests/integration/test_local_sql_overlays.py`
- Modify: `tools/verify.py`

**Interfaces:**
- Produces: one result per query with four axes: `static_valid`, `runtime_compatible`, `execution_verified`, and `semantic_verified`.
- Consumes: query manifests, stdlib index, overlays, owned fixtures, assertions, and locked processor.

- [ ] **Step 1: Write failing validation-axis tests**

Cover syntax failure, missing module/table/fragment/parameter/result dependency, processor failure, empty execution without assertion, semantic assertion pass/fail, and stale overlay regression ID.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_all_query_validation`

- [ ] **Step 3: Implement static validation for every query**

Validate all query IDs, hashes, templates, fragments, modules, required schema, result dependencies, API entries, and overlay linkage. Emit stable JSON with an entry for every query; never summarize away failures.

- [ ] **Step 4: Implement fixture-backed execution validation**

For each declared assertion, run the exact rendered query on the hashed owned fixture with the locked processor. Queries without a compatible fixture remain capability-gated/unverified and cannot become semantic verified.

- [ ] **Step 5: Enforce local SQL red-green metadata**

Every SQL overlay must resolve at least one assertion ID whose fixture is real and whose assertion fails against the recorded upstream base behavior but passes against the overlay. Store the base-failure signature so later syncs cannot erase the regression.

- [ ] **Step 6: Run all-query validation and complete affected graphs**

Run static validation across all catalog queries, semantic assertions, local overlay regressions, and complete Skill graph tests. Expected: zero errors; counts are computed, not hardcoded in docs.

- [ ] **Step 7: Add validation to the complete gate**

Default full verification runs all static checks and owned semantic assertions. Sync tier additionally runs migration/drift checks against checked-out upstreams.

---

### Task 7: Add upstream sync and canary CI

**Files:**
- Modify: `.github/workflows/upstream-sync.yml`
- Create: `.github/workflows/upstream-canary.yml`
- Modify: `docs/maintenance/upstream-sync.md`
- Modify: `AGENTS.md`
- Test: `tests/unit/test_release.py`

**Interfaces:**
- Produces: manual blocking sync workflow and scheduled non-blocking canary.
- Consumes: three sync tools, owned fixtures, locks, and drift reports.

- [ ] **Step 1: Extend workflow contract tests**

Require commit-pinned actions, read-only default permissions, explicit SmartPerfetto and Google repositories, dry-run sync commands, uploaded reports, and no automatic lock commit/push.

- [ ] **Step 2: Update blocking sync workflow**

Manual dispatch takes proposed SmartPerfetto commit and Perfetto tag inputs, checks them out read-only, runs all three sync tools without `--apply`, runs owned fixture/SQL validation, and uploads JSON/Markdown reports.

- [ ] **Step 3: Add scheduled canary**

Canary discovers latest official release and SmartPerfetto main, emits drift, and uses `continue-on-error` only for the canary validation step. It cannot alter supported locks.

- [ ] **Step 4: Document exact maintainer commands**

Include prepare, inspect, apply, verify, rollback, cross-repository impact decision, and release rules. Distinguish ordinary development from explicit sync.

- [ ] **Step 5: Run workflow/unit validation**

Expected: all workflow contract tests pass and YAML parses.

---

### Task 8: Complete verification, review, commits, and push

**Files:**
- Verify only; modify only confirmed findings.

- [ ] **Step 1: Run the independent Perfetto-Skills gate**

Run: `uv run python tools/verify.py`

Expected: all repository, compiler, runtime, owned fixture, query, Agent Skill, and release checks pass without SmartPerfetto.

- [ ] **Step 2: Run the pinned upstream sync gate**

Run the explicit sync command against the pinned SmartPerfetto and canonical Google Perfetto checkout. Expected: locks and committed reports are current; no unexpected generated diff.

- [ ] **Step 3: Run SmartPerfetto's relevant gates if required**

If the impact decision is `required`, run its focused Skill validation and `npm run verify:pr` before completion.

- [ ] **Step 4: Request independent read-only architecture and security review**

Review lock integrity, dry-run behavior, overlay staleness, query validation truthfulness, fixture safety, CI permissions, and cross-repository boundaries.

- [ ] **Step 5: Perform simplification review**

Use the available project simplifier; otherwise perform manual behavior-preserving review plus `git diff --check`. Only simplify changed code.

- [ ] **Step 6: Commit each repository separately**

Do not stage SmartPerfetto `.gitignore`. Record paired commit hashes in impact decisions.

- [ ] **Step 7: Push only after fresh complete gates**

Push SmartPerfetto and Perfetto-Skills `main`, monitor their GitHub Actions to success, and verify remote refs equal local commits.
