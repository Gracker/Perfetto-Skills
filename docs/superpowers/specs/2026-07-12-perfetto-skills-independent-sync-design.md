# Perfetto Skills Independent Development and Upstream Sync Design

**Status:** Proposed for implementation
**Date:** 2026-07-12
**Project:** Perfetto Skills

## 1. Context

Perfetto Skills began as a portable projection of SmartPerfetto's Skill,
Strategy, and SQL catalog. That relationship remains useful, but the public
project must now be independently developable and testable. A normal checkout
must be able to change a Skill or SQL query, run real-trace regression tests,
and publish a release without a sibling SmartPerfetto checkout.

The project still has three upstream relationships:

1. SmartPerfetto contributes domain Skills, Strategies, SQL, and product-earned
   performance-analysis knowledge.
2. Google's official Perfetto Skill contributes upstream Agent Skill structure,
   recording/querying guidance, and selected official workflows.
3. Google's Perfetto source tree and PerfettoSQL standard library define the
   trace processor release, RPC API, modules, tables, functions, and schema
   against which local SQL executes.

These inputs must be synchronized explicitly without making any of them a
runtime dependency or allowing a sync to overwrite local fixes silently.

## 2. Goals

- Make Perfetto Skills independently buildable, testable, and releasable.
- Keep SmartPerfetto, the official Perfetto Skill, and official PerfettoSQL
  synchronized through separate pinned inputs and reviewable reports.
- Give local Skill, Strategy, and SQL changes a first-class source location.
- Require every local SQL correction to carry provenance, rationale, and a
  real-trace regression test.
- Replace SmartPerfetto-owned test traces with a Perfetto-Skills-owned fixture
  pack and a very small committed real smoke trace.
- Add an explicit project-choice table to the English and Chinese READMEs of
  SmartPerfetto and Perfetto Skills.
- Add a bidirectional pre-commit impact review so an AI changing either
  repository must decide whether the paired repository needs a corresponding
  contract, content, runtime, test, or documentation update.
- Keep generated output deterministic and prohibit direct edits to it.

## 3. Non-goals

- Do not merge SmartPerfetto and Perfetto Skills release cycles.
- Do not install or invoke Google's official Perfetto Skill at runtime.
- Do not copy the entire Perfetto repository or stdlib source into the Agent
  Skill release.
- Do not claim that trace processor compatibility proves query semantics.
- Do not commit unreviewed, private, identifying, or secret-bearing traces.
- Do not automatically accept upstream changes merely because they compile.

## 4. User-facing project choice

The four top-level READMEs form one bilingual project-choice contract:

- `Gracker/SmartPerfetto/README.md`
- `Gracker/SmartPerfetto/README.zh-CN.md`
- `Gracker/Perfetto-Skills/README.md`
- `Gracker/Perfetto-Skills/README.zh-CN.md`

Each README adds the same three-project comparison immediately after its short
introduction and before setup instructions.

| Project | Form | Best for | Main capability boundary | Choose it when |
|---|---|---|---|---|
| SmartPerfetto | Full Web UI, CLI, backend, provider runtime | End-to-end interactive Android performance investigations | Perfetto UI plus managed Skill execution, reports, sessions, comparison, and provider integration | A complete analysis product is wanted |
| Perfetto Skills | Portable standard Agent Skill | Local agents with filesystem and terminal access | Deterministic portable Skill runner, evidence contracts, and broad SmartPerfetto-derived analysis coverage | Existing Codex, Claude Code, or OpenCode workflows should analyze local traces |
| Google official Perfetto Skill | Official upstream Agent Skill bundle | Upstream-first recording, memory, GPU, and ad-hoc PerfettoSQL guidance | Official Perfetto workflows and the bundled upstream trace processor environment | The smallest upstream-maintained starting point is preferred |

The rows link directly to both Gracker projects, the official Perfetto Skill
source, and the official Perfetto AI usage documentation. The comparison must
not describe the official Skill as a dependency or base layer for Perfetto
Skills.

## 5. Ownership model

The project is split into four ownership layers:

```text
upstream locks -> imported snapshots -> local source/overlays -> generated Skill
                                      -> project-owned fixtures -> verification
```

### 5.1 Upstream locks

`upstreams/` contains machine-readable locks and import metadata:

```text
upstreams/
├── smartperfetto.lock.json
├── google-perfetto.lock.json
├── fixture-pack.lock.json
└── snapshots/
    ├── smartperfetto/
    └── google-perfetto/
```

Locks record repository URL, immutable commit, tag where applicable, source
paths, source hashes, license, importer version, and import time. The Google
Perfetto lock additionally records RPC API, stdlib tree ID, official Skill file
hashes, and trace processor artifact hashes.

Snapshots are sync inputs. They are never edited by hand.

### 5.2 Local source and overlays

Independent development lives under `src/`:

```text
src/
├── skills/
├── strategies/
├── sql/
└── overrides/
    ├── skills/
    ├── strategies/
    └── sql/
```

A native local asset has no upstream base. An overlay targeting an imported
asset declares:

- stable target ID;
- expected upstream SHA-256;
- reason for divergence;
- behavior or schema change;
- associated regression test IDs;
- whether the change should later be proposed upstream.

The compiler refuses a stale overlay when its expected upstream hash no longer
matches. This turns upstream drift into a review task instead of silently
reapplying an old patch to new content.

### 5.3 Generated runtime

The existing `skills/perfetto-performance-analysis/references/generated/`
tree remains generated output. `tools/compile_skill.py` deterministically merges
the imported snapshots with local source and overlays. Generated files must not
be edited directly.

The release Skill remains self-contained and does not contain the upstream
checkouts, fixture pack, or synchronization tools unless they are required for
normal runtime use.

## 6. Synchronization contracts

### 6.1 SmartPerfetto synchronization

`tools/sync_smartperfetto.py` accepts either an explicit checkout or an
immutable repository/commit pair. It:

1. verifies repository identity, commit, clean input state, public export
   policy, and license;
2. imports the declared Skill, Strategy, fragment, vendor override, pipeline,
   and SQL sources into a new temporary snapshot;
3. emits added, removed, changed, reclassified, and contract-breaking items;
4. checks every local overlay against the new base hash;
5. compiles to a temporary generated tree and produces a deterministic diff;
6. never writes the accepted snapshot without an explicit `--apply`;
7. requires the full sync verification tier before the lock can change.

SmartPerfetto remains an optional upstream. Ordinary development and CI use the
committed snapshot and do not clone SmartPerfetto.

### 6.2 Google official Skill synchronization

`tools/sync_official_skill.py` reads the official Skill paths from the pinned
Google Perfetto release. It does not install the official Skill or copy it into
the portable runtime as a dependency. It produces:

- source path and hash inventory;
- router/workflow additions and removals;
- changes to querying, recording, identity, duration, schema-discovery, and
  stdlib-first guidance;
- a structured gap report classifying each change as adopted, already covered,
  not applicable, or pending review;
- retained Apache-2.0 provenance for any deliberately reused material.

Updating the gap report is not sufficient to claim compatibility. Adopted
behavior must have a local source change and tests.

### 6.3 Perfetto release and PerfettoSQL synchronization

`tools/sync_perfetto_stdlib.py` synchronizes the official release substrate:

1. resolve the canonical Google tag to its peeled commit;
2. verify the expected RPC API and trace processor artifact hashes;
3. record the stdlib tree ID and rebuild module/symbol/schema indexes;
4. compare modules, tables, columns, functions, macros, and relevant semantic
   documentation with the previous lock;
5. statically revalidate every local SQL template and dependency graph;
6. execute all eligible queries against the project-owned fixture matrix;
7. emit a query-by-query migration report;
8. run new releases first as a non-blocking canary;
9. change the supported lock only after blocking validation succeeds.

Official stdlib synchronization and local SQL synchronization are separate.
The former describes the execution substrate; the latter controls
SmartPerfetto-derived and Perfetto-Skills-native analysis queries.

### 6.4 Bidirectional SmartPerfetto impact review

Independent release cycles do not remove the need for cross-repository impact
review. Every relevant commit in either project must classify its effect on the
paired repository before commit or push.

SmartPerfetto triggers include changes to:

- `backend/skills/`, `backend/strategies/`, public export policy, fragments, or
  vendor overrides;
- the Skill loader, validator, executor, expression runtime, identity or
  evidence contracts, deterministic claim verifier, report contract, or
  comparison semantics;
- Perfetto pins, stdlib/schema indexes, trace processor adapters, and fixture
  assertions used by the public export.

Perfetto-Skills triggers include changes to:

- SmartPerfetto imports, locks, snapshots, overlays, or compiler behavior;
- the portable Skill runner, expression evaluator, identity/evidence/report
  contracts, comparison adapter, query runtime, or compatibility states;
- SmartPerfetto-derived SQL, Strategy, pipeline, vendor, fixture, or semantic
  assertions that may expose a source-product bug or reusable improvement.

The review result is recorded as exactly one of:

- `required`: update the paired repository in the same task before declaring
  completion, unless that repository cannot be changed safely;
- `not_required`: record the concrete boundary that makes the change local;
- `deferred`: record the required follow-up, reason it cannot be completed in
  the current task, and a durable issue or handoff reference.

`tools/check_cross_repo_impact.py` classifies the changed paths and prints the
required checklist. It does not decide product semantics automatically. The AI
must inspect the actual diff and paired contracts. If the sibling checkout is
available, a `required` decision runs its relevant validation too. If it is not
available, the decision is still mandatory and uses the committed lock/catalog
as the comparison boundary.

The two directions are intentionally different:

- SmartPerfetto to Perfetto-Skills is an explicit import/sync operation.
- Perfetto-Skills to SmartPerfetto is an upstream-candidate review; local
  overlays are not copied mechanically into SmartPerfetto. The source product
  receives only changes that match its architecture and tests.

This review is a repository-maintenance rule, not a runtime dependency between
the installed products.

## 7. Local SQL modification contract

A local SQL fix follows a mandatory red-green workflow:

1. Identify the query ID and current base/source hash.
2. Add or select a project-owned real trace that reproduces the issue.
3. Add a failing assertion that distinguishes the bug from a legitimate empty
   or unavailable signal.
4. Place the corrected SQL in `src/sql/` or `src/overrides/sql/`; never edit
   generated SQL.
5. Declare module, table, column, fragment, parameter, prior-result, and output
   dependencies.
6. Run static validation and locked-processor prepare/execute validation.
7. Run the semantic assertion on the reproducing trace.
8. Run affected complete Skill graphs so a query fix cannot break condition,
   identity, optional, iterator, evidence, or report behavior.
9. Run negative and missing-capability cases.
10. Record the query source hash, rendered SQL hash, fixture hash, processor
    identity, and expected result contract in the validation report.

A query may be labeled `semantic_verified` only when its fixture has meaningful
column/value/relation assertions. Parse success or empty output is insufficient.

## 8. Project-owned real trace fixtures

### 8.1 Storage

Perfetto Skills owns a versioned fixture pack published as a GitHub Release
asset. `fixtures/manifest.json` and `upstreams/fixture-pack.lock.json` record the
asset URL, SHA-256, archive layout, and individual trace hashes.

One very small sanitized real trace is committed under `fixtures/smoke/`. It
supports offline bootstrap tests without downloading the fixture pack. Larger
traces remain outside Git history and outside the installable Skill archive.

### 8.2 Required metadata

Every trace records:

- project fixture ID and immutable SHA-256;
- real or synthetic status; release-blocking semantic fixtures must be real;
- capture owner/source and redistribution permission;
- sanitization and privacy review status;
- Android/API/QPR, OEM/device class, kernel, build type, ABI;
- recording config and setup errors;
- intended capabilities and intentionally absent capabilities;
- expected Skill/query assertions;
- minimum and maximum supported trace processor lock where known.

Trace contents are scanned for secrets, user identifiers, private paths,
account data, and unexpected package/process names before publication.

### 8.3 Initial matrix

The first owned pack should cover at least:

- cold and warm startup;
- standard Android View scrolling/jank;
- Flutter SurfaceView or TextureView rendering;
- ANR or main-thread blocking;
- Java/native memory evidence;
- callstack sampling;
- one GPU-populated trace and one explicitly not-recorded GPU trace;
- one capability-negative or recorded-empty trace.

Existing SmartPerfetto traces may seed the pack only after explicit
redistribution and privacy review. Once copied into the owned pack, they have
Perfetto-Skills fixture IDs and no runtime path dependency on SmartPerfetto.

## 9. Verification tiers

### Tier 0: repository and offline smoke

Runs on every change without SmartPerfetto or network access:

- repository/Agent Skill validation;
- compiler determinism;
- lock/overlay schema validation;
- unit tests;
- committed real smoke trace execution;
- generated-tree drift check.

### Tier 1: owned fixture regression

Downloads the checksum-pinned Perfetto-Skills fixture pack and runs:

- complete representative Skill graphs;
- query semantic assertions;
- empty/error/missing-capability distinctions;
- evidence/report/identity validation;
- comparison and negative tests.

This is the normal PR and release gate.

### Tier 2: SQL and Android compatibility matrix

Shards all queries across compatible owned fixtures and records, per query and
API/capability profile:

- static validity;
- runtime compatibility;
- execution verification;
- semantic verification;
- output schema and invariant results;
- unsupported, not-recorded, recorded-empty, recorded-populated, or unknown
  capability state.

API level remains an adapter hint. No matrix entry becomes verified solely
from an Android version number.

### Tier 3: upstream synchronization gate

Runs only for explicit sync PRs. It checks out the locked SmartPerfetto and
Google Perfetto inputs, regenerates snapshots and indexes, validates overlay
base hashes, and requires a reviewed migration report.

### Tier 4: upstream canary

A scheduled non-blocking workflow tests the newest official Perfetto release
and selected SmartPerfetto main commits. It opens or updates a drift report but
does not change locks automatically.

## 10. Project rules

`AGENTS.md` remains the short mandatory entry point. It will state:

- Perfetto Skills is independently owned; upstreams are synchronized inputs.
- ordinary tests must not require a SmartPerfetto checkout;
- generated files are changed only through importer/compiler sources;
- which rule/document to read before each of the three sync operations;
- the mandatory SQL red-green real-trace workflow;
- the owned fixture privacy, license, checksum, and metadata rules;
- the bidirectional SmartPerfetto/Perfetto-Skills impact review and its
  `required`, `not_required`, and `deferred` outcomes;
- the exact verification tier required before a commit, PR, tag, or release.

Detailed durable instructions live in
`docs/maintenance/upstream-sync.md`, with commands, expected artifacts,
failure handling, review checklist, and rollback procedure.

SmartPerfetto mirrors the cross-repository rule in its root `AGENTS.md` and
`CLAUDE.md`, with detailed triggers and commands in
`.claude/rules/skills.md`. Perfetto-Skills keeps the corresponding entry in its
root `AGENTS.md` and detailed workflow in `docs/maintenance/upstream-sync.md`.
Tests assert that the adapters still contain the required routing text so one
agent surface cannot silently lose the check.

## 11. CI and release behavior

Normal CI checks out only Perfetto Skills, downloads its own fixture pack, and
uses its own trace processor lock. SmartPerfetto is not cloned.

Sync CI is a separate manual/scheduled workflow with read-only upstream
checkouts. It cannot write locks or generated assets automatically.

Release CI requires Tier 0, Tier 1, and the release-blocking parts of Tier 2.
Release archives exclude fixture traces, upstream snapshots, development-only
indexes, and sync credentials. They retain the runtime locks and provenance
needed to verify the installed Skill.

## 12. Migration

1. Add the README comparison and maintenance rules.
2. Add the bidirectional impact classifier and rule-presence tests in both
   repositories.
3. Introduce lock, snapshot, local-source, overlay, and compiler schemas while
   preserving current generated runtime behavior.
4. Publish and validate the first owned fixture pack plus committed smoke trace.
5. Change default verification to owned fixtures and remove the SmartPerfetto
   fixture/environment requirement.
6. Split current exporter behavior into explicit SmartPerfetto import and local
   compile phases.
7. Add official Skill and stdlib sync reports.
8. Make upstream canaries scheduled and keep release gates on pinned inputs.

At each migration step, the current public Skill must remain installable and
the generated runtime must stay deterministic.

## 13. Acceptance criteria

- All four READMEs contain the aligned three-project comparison and valid links.
- `AGENTS.md` routes all three sync types, local SQL changes, and fixture work to
  explicit rules.
- Normal verification succeeds from a fresh Perfetto-Skills checkout without a
  SmartPerfetto checkout.
- The committed smoke trace and downloaded fixture pack are project-owned,
  hashed, licensed, privacy-reviewed, and exercised in CI.
- SmartPerfetto sync, official Skill sync, and stdlib sync each produce an
  independent lock update and reviewable diff/report.
- Local overlays survive upstream sync and fail closed when their base hash is
  stale.
- Relevant commits in either repository produce a reviewed cross-repository
  impact decision, and `required` changes cannot be declared complete while the
  paired update is silently omitted.
- Every local SQL fix has a real-trace regression assertion and complete-Skill
  regression coverage.
- Generated assets cannot drift from snapshots plus local source/overlays.
- Release verification never relies on SmartPerfetto services, checkout paths,
  or test traces.
