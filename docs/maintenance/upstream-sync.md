# Upstream synchronization and local SQL maintenance

Perfetto Skills is released and tested independently. SmartPerfetto and Google
Perfetto are reviewed upstream inputs, not runtime dependencies. All supported
upstream state is immutable, checksum-pinned, dry-run by default, and promoted
only after project-owned real-trace verification.

## Cross-repository impact decision

Run the impact checker before committing or pushing. Its path classifier only
answers whether review is needed; a maintainer or agent must supply the semantic
decision.

```bash
base="$(git merge-base HEAD origin/main)"
uv run python tools/check_cross_repo_impact.py \
  --repository perfetto-skills --base "$base" \
  --decision required --reason "paired runtime contract changed" \
  --paired-path /absolute/path/to/SmartPerfetto \
  --paired-ref "$(git -C /absolute/path/to/SmartPerfetto rev-parse HEAD)"
```

The public triggers are `catalog/`, runtime scripts and assets, generated
references, `src/`, `upstreams/`, `fixtures/`, the SmartPerfetto exporter, and
the local compiler. The decisions mean:

- `required`: validate `--paired-path` and require `--paired-ref` to name both
  an existing commit and the paired checkout's exact HEAD, change the paired
  repository, and run both repositories' gates;
- `not_required`: explain why the behavior or contract is local;
- `deferred`: explain the split and provide a durable issue, commit, or PR
handoff with `--handoff`.

The default input is the union of merge-base-to-HEAD, staged, unstaged, and
untracked paths. Record the emitted change fingerprint and paired evidence in
commit or PR notes. If a required paired checkout/ref cannot be validated, use
`deferred` with a stable shared issue/task URL.

An overlay is a reviewed public-project divergence. Never copy it mechanically
into SmartPerfetto. Re-express the behavior in SmartPerfetto's architecture,
add its native tests, then regenerate the public projection if appropriate.

## Synchronize SmartPerfetto Skills, Strategies, and SQL

1. Pin the reviewed SmartPerfetto repository and 40-character commit in
   `upstreams/smartperfetto.lock.json`.
2. Run `uv run python tools/sync_smartperfetto.py --source PATH --report-dir
   test-output/sync`. This imports into a temporary directory and reports
   added, removed, changed, and overlay-conflicting files without mutation.
3. Inspect the report and update SmartPerfetto export policy at its source when
   a product-owned Skill, Strategy, rendering-pipeline document, or SQL query is
   missing.
4. Apply an approved import with the same command plus `--apply`, then compile
   local overlays with `uv run python tools/compile_skill.py --apply`.
5. Run the complete independent gate and the explicit pinned upstream gate.
   Record the cross-repository impact decision and paired commit when required.

Only files marked `GENERATED FILE` or listed in the generated-base manifest are
compiler output. The portable runtime under `scripts/` is native
Perfetto-Skills source. Modify generated assets through the exporter, imported
base, or an explicit local overlay; never hand-edit a generated file.

## Synchronize the Google official Perfetto Skill

The official Skill is a gap-check-only upstream. It is not a base package or a
runtime dependency.

1. Pin the canonical tag, peeled commit, and official Skill subtree in
   `upstreams/google-perfetto.lock.json`.
2. Run `uv run python tools/sync_official_skill.py --perfetto PATH --report-dir
   test-output/sync`.
3. Classify every current or removed file as `adopted`, `already_covered`,
   `not_applicable`, or `pending_review`. The synchronizer applies only an
   exact `(path, SHA-256)` decision; unchanged files do not inherit an outcome
   from their directory. Record a non-pending result in
   `upstreams/official-skill-decisions.json` with a concrete reason.
   `adopted` and `already_covered` additionally require the implementing local
   path, stable test id, and exact 40-character reviewed source commit.
   `not_applicable` must explain the missing product/runtime boundary rather
   than imply implementation. Unknown fields, malformed hashes, duplicate
   decisions, and unresolved paths make pinned synchronization and `--apply`
   fail.
4. If adopted, implement it through this repository's normal source and tests,
   then refresh the snapshot with `--apply`; the tool refreshes the lock's
   complete snapshot hash before the complete gate runs.

## Synchronize the official PerfettoSQL library

1. Verify that tag, peeled commit, RPC API, trace-processor binary lock, and
   stdlib tree ID agree in `upstreams/google-perfetto.lock.json`.
2. Run `uv run python tools/sync_perfetto_stdlib.py --perfetto PATH
   --report-dir test-output/sync` to index modules, exported symbols, hashes,
   documentation, and parse warnings through `git ls-tree` and `git show`.
3. Resolve every removed/changed dependency and parse warning. Do not promote a
   lock while an imported query references an unresolved module or symbol.
4. Apply the reviewed index with `--apply`; the tool refreshes the complete
   stdlib snapshot hash in the Google lock. Bootstrap the locked processor, then run
   `uv run python tools/validate_all_queries.py` plus the complete gate. The
   scheduled canary additionally downloads the newest tagged official processor,
   verifies its tag/commit/RPC identity, and executes owned real-trace semantic
   assertions with the current Skill queries without promoting that processor.

## Modify local SQL safely

Local SQL replacements live under `src/overrides/sql/` with a descriptor that
records the target, expected upstream SHA-256, replacement SHA-256, reason,
owned-fixture regression IDs, and upstream-candidate state. Full replacement
files make review and rebasing explicit.

Overlay descriptors use the `*.overlay.json` suffix. Skill and Strategy
overlays must list every dependent index/catalog replacement with both the
expected upstream SHA-256 and replacement SHA-256; compilation stops if either
the primary target or any dependent base changed.

Use this red-green sequence:

1. Add or identify a project-owned real-trace assertion that fails against the
   recorded upstream base SQL; record its stable failure signature.
2. Add the overlay descriptor and replacement. Run its focused regression and
   confirm the base fails while the replacement passes.
3. Run `uv run python tools/compile_skill.py --check` and
   `uv run python tools/validate_all_queries.py`. Static validation parses SQL
   after bounded Perfetto-template normalization and checks parameters,
   fragments, setup/result dependencies, required symbols, hashes, and API
   coverage. Every query also reports processor-compatibility, execution, and
   semantic-verification axes; only the owned assertions executed by the full
   gate count as current execution evidence.
4. Run `uv run python tools/verify.py` with the checksum-verified fixture pack.
5. Run the impact checker and update SmartPerfetto when the decision is
   `required`.

After any upstream sync, stale expected base hashes fail compilation instead of
silently dropping or overwriting the local fix. Re-run the original regression,
review whether the overlay is still needed, and either rebase it, remove it
because upstream fixed the issue, or retain it with a new reviewed base hash.

## Publish and consume project-owned fixtures

Fixture packs are independent releases and are never rewritten. Before a new
tag, run the v2 scanner over every manifest trace, review the private printable
package/process inventory, and record the maintainer attestation without
committing the identifier strings themselves:

```bash
uv run python tools/scan_fixture_privacy.py TRACE... \
  --approve-identifiers REVIEWER --reviewed-at YYYY-MM-DD \
  --output fixtures/privacy-scan-v2.json
uv run python tools/build_fixture_pack.py \
  --manifest fixtures/manifest.json --source-root FIXTURE_ROOT \
  --output perfetto-skills-fixtures-v2.tar.gz
```

The deterministic archive builder rejects any trace set that is not covered
exactly by the committed v2 privacy report or whose identifier review is not
approved. It packages that report, `NOTICE`, and the AGPL/Apache license texts;
the downloader verifies their lock-file hashes on every cache reuse. Commit the
manifest, report, licenses, lock, and builder changes before creating the tag,
then rebuild from that clean tagged commit and compare the archive SHA-256
before publishing. A later pack uses a new version and release tag; never
replace an existing asset.

## Rollback

Locks, generated-base snapshots, reports, and fixture locks are ordinary
versioned files. If promotion fails, abandon the uncommitted applied output or
revert the synchronization commit, restore the previous immutable locks, clear
only the local test cache, and rerun the prior complete gate. Never rewrite an
existing fixture release asset or supported upstream tag.
