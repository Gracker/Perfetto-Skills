# Project-Owned Trace Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Perfetto-Skills real-trace verification independent of SmartPerfetto by publishing a checksum-pinned project-owned fixture pack and committing one small real smoke trace.

**Architecture:** Fixture metadata and a small Apache-licensed real trace live in Git. Larger real traces are packaged reproducibly as a `fixtures-v1` GitHub Release asset, downloaded into a cache, and verified file-by-file. Normal CI uses only Perfetto-Skills plus its fixture pack and processor lock; SmartPerfetto checkout is reserved for explicit sync CI.

**Tech Stack:** Python 3.11 standard library, tar.gz, JSON manifests, GitHub Releases, Python `unittest`, GitHub Actions.

## Global Constraints

- Never publish a trace before license, provenance, privacy, and SHA-256 metadata are present.
- Release Skill archives must not contain fixture traces.
- Normal `uv run python tools/verify.py` must not require SmartPerfetto.
- Keep `--smartperfetto` as a temporary explicit sync compatibility path until the upstream-sync plan replaces it.
- The fixture pack is immutable; changes publish a new fixture version and lock.
- Use the locked v57.2 trace processor for release-blocking assertions.

---

### Task 1: Define and validate the owned fixture manifest

**Files:**
- Create: `fixtures/manifest.json`
- Create: `fixtures/README.md`
- Create: `tools/fixture_manifest.py`
- Create: `tests/unit/test_owned_fixture_manifest.py`

**Interfaces:**
- Produces: `load_manifest(path: Path) -> dict`, `validate_manifest(manifest: dict) -> list[str]`, and `sha256_file(path: Path) -> str`.
- Consumes: fixture metadata copied from the reviewed SmartPerfetto public manifest and upstream Perfetto checksums.

- [ ] **Step 1: Write failing schema tests**

Tests require each fixture to contain `id`, `path`, `sha256`, `license`, `origin`, `real`, `privacy_review`, `capture`, `platform`, `capabilities`, and `assertions`. Reject duplicate IDs/paths, unsafe paths, non-hex hashes, `real: false` for release-blocking assertions, and missing redistribution review.

- [ ] **Step 2: Run the tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_owned_fixture_manifest`

Expected: FAIL because the manifest module does not exist.

- [ ] **Step 3: Implement the manifest validator**

Use only standard-library types. `validate_manifest` returns stable sorted issue strings; CLI callers fail if the list is non-empty.

- [ ] **Step 4: Create manifest v1**

Use project fixture IDs independent of source paths. Include the six already-public SmartPerfetto traces and the five Apache-2.0 upstream Perfetto traces. Record original repository/path and current SHA-256. Mark unknown metadata explicitly as `unknown`, never infer it.

- [ ] **Step 5: Run manifest tests**

Run: `uv run python -m unittest tests.unit.test_owned_fixture_manifest`

Expected: PASS with all source trace hashes and metadata present.

---

### Task 2: Add deterministic fixture pack build and download

**Files:**
- Create: `tools/build_fixture_pack.py`
- Create: `tools/download_fixture_pack.py`
- Create: `tests/unit/test_fixture_pack.py`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `build_pack(manifest_path: Path, source_root: Path, output: Path) -> Path` and `download_pack(lock_path: Path, cache_root: Path) -> Path`.
- Consumes: manifest relative paths and lock URL/hash.

- [ ] **Step 1: Write failing reproducibility and safety tests**

Tests require byte-identical two-build output, sorted archive entries, timestamp/uid/gid normalization, rejection of symlinks/path traversal, archive-level hash verification, and per-file hash verification after extraction.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_fixture_pack`

Expected: FAIL because builder/downloader modules do not exist.

- [ ] **Step 3: Implement deterministic tar.gz creation**

Use `tarfile` with each `TarInfo` normalized to `mtime=0`, `uid=gid=0`, empty owner/group names, mode `0o644`, and lexicographic order. Gzip uses `mtime=0` and an empty stored filename.

- [ ] **Step 4: Implement atomic download and extraction**

Download to a temporary file, verify archive SHA-256, reject unsafe members, extract to a temporary directory, verify every manifest file, then atomically rename to `cache_root / lock["version"]`.

- [ ] **Step 5: Run fixture pack unit tests**

Run: `uv run python -m unittest tests.unit.test_fixture_pack`

Expected: PASS.

- [ ] **Step 6: Ignore local fixture caches**

Add `.perfetto-fixtures/` and `test-output/fixtures/` to `.gitignore` without ignoring `fixtures/smoke/`.

---

### Task 3: Commit auditable fixture inputs, then publish fixture pack v1

**Files:**
- Create: `fixtures/smoke/api32_startup_warm.perfetto-trace`
- Modify: `fixtures/manifest.json`
- Create: `upstreams/fixture-pack.lock.json`

**Interfaces:**
- Consumes: Google Perfetto's tracked `api32_startup_warm.perfetto-trace` at the locked v57.2 source, plus the reviewed source directory for all fixture-pack inputs.
- Produces: committed offline smoke data and public immutable pack asset.

- [ ] **Step 1: Copy and verify the smoke trace**

Copy the 1.9 MiB Apache-2.0 API 32 warm-start trace into `fixtures/smoke/`. Verify its hash against the official `.sha256` file and record provenance in the manifest.

- [ ] **Step 2: Scan candidate pack traces**

Run printable-string scans for email addresses, bearer/API key patterns, private home paths, account identifiers, and unexpected package/process names. Record the review result in each manifest entry. Do not publish a failing trace.

- [ ] **Step 3: Build the deterministic pack twice**

Run:

```bash
uv run python tools/build_fixture_pack.py --manifest fixtures/manifest.json \
  --source-root /tmp/perfetto-skills-fixtures-v1-source \
  --output /tmp/fixtures-a.tar.gz
uv run python tools/build_fixture_pack.py --manifest fixtures/manifest.json \
  --source-root /tmp/perfetto-skills-fixtures-v1-source \
  --output /tmp/fixtures-b.tar.gz
shasum -a 256 /tmp/fixtures-a.tar.gz /tmp/fixtures-b.tar.gz
cmp /tmp/fixtures-a.tar.gz /tmp/fixtures-b.tar.gz
```

Expected: identical hashes and `cmp` exit 0.

- [ ] **Step 4: Fill the immutable lock hashes**

Replace the lock's archive and manifest hashes with computed lowercase SHA-256 values; rerun manifest/pack tests.

- [ ] **Step 5: Commit all release inputs before tagging**

Commit the validated manifest, smoke trace, builder/downloader, provisional lock
containing the final archive/manifest hashes, privacy evidence, and tests. From a
clean checkout of that commit, rebuild the archive twice and verify identical
hashes. The provisional URL may use the deterministic release URL for
`fixtures-v1`; its content hash is already final.

- [ ] **Step 6: Publish the fixture release**

Create annotated tag `fixtures-v1` at the committed, clean, rebuildable input
commit, then publish the archive, `fixtures/manifest.json`, and generated
`SHA256SUMS` to a GitHub Release named `fixtures-v1`. This tag must not match the
product `v*` release workflow.

- [ ] **Step 7: Download the public asset into an empty cache**

Run: `uv run python tools/download_fixture_pack.py --cache /tmp/perfetto-skills-fixture-smoke`

Expected: archive and all individual files verify; output prints the resolved fixture root.

---

### Task 4: Refactor integration tests to project-owned fixture IDs

**Files:**
- Modify: `tests/support.py`
- Modify: `tests/integration/test_fixture_manifest.py`
- Modify: `tests/integration/test_skill_runner.py`
- Modify: `tests/integration/test_real_trace.py`
- Modify: `tests/integration/test_pipeline.py`
- Modify: `tests/integration/test_comparison.py`
- Delete: `tests/fixtures/README.md`
- Test: the affected integration suite.

**Interfaces:**
- Produces: `fixture_path(fixture_id: str) -> Path` using `PERFETTO_FIXTURE_ROOT`, with the committed smoke root as Tier 0 fallback.
- Consumes: `fixtures/manifest.json` IDs rather than SmartPerfetto-relative paths.

- [ ] **Step 1: Write a failing fixture lookup test**

Add a unit test that resolves a manifest ID, rejects an unknown ID, and verifies the file hash before returning it.

- [ ] **Step 2: Run the test and verify it fails**

Expected: FAIL because `fixture_path` does not exist.

- [ ] **Step 3: Implement ID-based fixture lookup**

Remove `SMARTPERFETTO_TEST_TRACES` and `SMARTPERFETTO_SOURCE` from ordinary integration paths. Tests receive the owned fixture root and use IDs such as `startup-light-api36`, `scroll-aosp-api35`, `flutter-texture-api35`, `callstack-sampling`, and `startup-api32-warm-smoke`.

- [ ] **Step 4: Preserve semantic assertions**

Map the existing nine assertions to owned fixture IDs. Keep strict `non_empty`, `field_equals`, and `field_positive` semantics.

- [ ] **Step 5: Run smoke integration**

Run with the committed smoke root and locked processor. Expected: the smoke query assertion passes and larger scenarios skip only in explicit `--offline` mode.

- [ ] **Step 6: Run full owned-fixture integration**

Download `fixtures-v1`, set `PERFETTO_FIXTURE_ROOT`, and run all integration tests. Expected: no SmartPerfetto environment variables or paths are used.

---

### Task 5: Make default verification and CI independent

**Files:**
- Modify: `tools/verify.py`
- Modify: `tests/unit/test_verify.py`
- Modify: `.github/workflows/verify.yml`
- Modify: `.github/workflows/release.yml`
- Create: `.github/workflows/upstream-sync.yml`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Produces: default owned-fixture verification, `--offline` smoke tier, and `--smartperfetto` explicit sync tier.
- Consumes: processor bootstrap and fixture pack downloader.

- [ ] **Step 1: Write failing verify-command tests**

Tests require default commands to download/resolve the owned pack, configure the locked processor, run all tests, validate the Skill, and avoid SmartPerfetto. `--smartperfetto` alone adds export/catalog drift checks.

- [ ] **Step 2: Run tests and verify they fail**

Run: `uv run python -m unittest tests.unit.test_verify`

Expected: FAIL because current default verification omits real traces and CI clones SmartPerfetto.

- [ ] **Step 3: Refactor verify environment resolution**

Resolve processor from `PERFETTO_TRACE_PROCESSOR` or checksum-pinned bootstrap. Resolve fixture root from explicit `--fixtures`, verified cache/download, or committed smoke for `--offline`. Export `PERFETTO_FIXTURE_ROOT` only.

- [ ] **Step 4: Simplify normal and release workflows**

Remove SmartPerfetto checkout, submodule checkout, and official-tag fetch from normal `verify.yml` and release verification. Run `uv run python tools/verify.py`.

- [ ] **Step 5: Add explicit upstream sync workflow**

The manual/scheduled workflow checks out pinned SmartPerfetto and official Perfetto source, then runs `tools/verify.py --smartperfetto ../SmartPerfetto`. Keep read-only permissions and upload drift reports.

- [ ] **Step 6: Update README and Agent rules**

Document that normal development uses project-owned traces. Put SmartPerfetto only under explicit upstream synchronization instructions.

- [ ] **Step 7: Run the complete independent gate**

From a checkout with no sibling SmartPerfetto path available, run:

```bash
uv run python tools/verify.py
```

Expected: all unit/integration tests and Agent Skill validation pass using owned assets.

- [ ] **Step 8: Commit fixture independence**

Commit the integration-test, CI, and documentation switch after the public
fixture asset exists. The release inputs themselves were already committed
before the `fixtures-v1` tag; never move or recreate that tag.

---

### Task 6: Independent review and remote verification

**Files:**
- Verify only.

- [ ] **Step 1: Run `git diff --check` and the full independent gate**

Expected: exit 0 with explicit test count and no skips for Tier 1 scenarios.

- [ ] **Step 2: Request read-only fixture/security review**

Review provenance, licenses, manifest metadata, privacy scan evidence, archive extraction safety, CI independence, and release exclusion.

- [ ] **Step 3: Verify the product release builder excludes traces**

Build both release archive formats and assert no `.pftrace`, `.perfetto-trace`, fixture pack, or fixture cache member exists.

- [ ] **Step 4: Fix confirmed findings and rerun the relevant full gate**

Expected: final independent verification remains green.
