# Perfetto Skills Public Repository Design

## Status

Approved for execution by the maintainer on 2026-07-11 with the instruction to
continue until the public repository is complete. The repository and local
directory name are `Perfetto-Skills`.

## Problem

SmartPerfetto contains a mature Perfetto analysis knowledge base, but its
current executable form is coupled to SmartPerfetto's YAML Skill DSL, Express
services, MCP registry, provider runtimes, session state, DataEnvelope output,
reports, snapshots, and UI teaching surfaces. Users who only want the analysis
expertise cannot install those capabilities as ordinary Agent Skills.

An older `Skills-Standard` export is not a viable base. It covered only startup
and scrolling, duplicated a platform-specific trace processor binary, contained
stale links, had no release validation, and was removed from SmartPerfetto after
its duplicated knowledge drifted away from `backend/skills/`.

## Goals

1. Publish an independent public GitHub repository named `Perfetto-Skills`.
2. Provide standards-compliant Agent Skills that work without the
   SmartPerfetto backend or UI.
3. Preserve the useful analysis coverage of every current runtime SmartPerfetto
   Skill, including atomic SQL evidence, composite workflows, module expertise,
   comparison methodology, and rendering-pipeline knowledge.
4. Migrate methodology currently embedded in strategies and workflow services
   when it is domain knowledge rather than product infrastructure.
5. Make local Perfetto SQL execution available through a small cross-platform
   adapter around `trace_processor_shell`.
6. Keep SmartPerfetto as the domain source of truth while making drift between
   the two repositories detectable and reproducible.
7. Ship installation, validation, real-trace smoke tests, release metadata, and
   contributor documentation suitable for public use.

## Non-goals

- Reimplement SmartPerfetto's web UI, Provider Manager, AI runtime adapters,
  SSE session protocol, reports, snapshots, RBAC, tenant Skill packs, or UI
  pin/overlay actions.
- Treat SmartPerfetto YAML files as if they were natively executable Agent
  Skills.
- Publish hundreds of top-level `SKILL.md` entries and force every agent to
  ingest a large, conflicting activation catalog.
- Bundle unsigned or platform-specific trace processor binaries in every
  Skill directory.
- Preserve obsolete heuristics from legacy TypeScript analysis templates when
  current validated YAML Skills and strategies supersede them.

## Standards Baseline

The portable core follows the open Agent Skills specification:

- each discoverable Skill is a directory whose name matches its frontmatter
  `name`;
- `SKILL.md` starts at byte zero with YAML frontmatter;
- portable metadata uses only `name`, `description`, `license`,
  `compatibility`, and string-valued `metadata`;
- detailed content is progressively disclosed through `references/`,
  `scripts/`, and `assets/`;
- client-specific metadata is isolated in adapter files and is never required
  for core behavior.

Canonical content lives under `skills/`. Installers copy or link the same tree
into `.agents/skills`, `.claude/skills`, or `.opencode/skills`; there are no
separate Claude, Codex, and OpenCode copies.

## Chosen Architecture

### One portable analysis Skill with internal workflow routing

The public runtime exposes one broad Skill named
`perfetto-performance-analysis`. SmartPerfetto's 230 runtime Skill candidates
become an internal evidence and workflow catalog rather than 230 top-level
activation entries.

This choice follows three constraints:

1. every top-level Agent Skill adds always-loaded discovery metadata;
2. the open standard does not define portable Skill-to-Skill dependency or
   invocation semantics;
3. Perfetto workflows share schema discovery, time units, identity resolution,
   evidence rules, and one trace processor runtime.

The main `SKILL.md` stays below the recommended activation-context budget and
acts as a router. It selects a workflow, requires capability checks before
queries, delegates deterministic work to scripts, and reads only the relevant
reference files.

### Repository layout

```text
Perfetto-Skills/
├── README.md
├── LICENSE
├── NOTICE
├── SECURITY.md
├── CONTRIBUTING.md
├── AGENTS.md
├── pyproject.toml
├── skills/
│   └── perfetto-performance-analysis/
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── perfetto_query.py
│       │   ├── perfetto_probe.py
│       │   └── bootstrap_trace_processor.py
│       ├── references/
│       │   ├── workflows/
│       │   ├── evidence/
│       │   ├── knowledge/
│       │   ├── pipelines/
│       │   └── sql/
│       └── assets/
│           ├── report-schema.json
│           └── workflow-index.json
├── adapters/
│   ├── codex/
│   ├── claude-code/
│   └── opencode/
├── catalog/
│   ├── smartperfetto-export.json
│   ├── workflow-index.json
│   └── trace-processor-lock.json
├── tools/
│   ├── export_from_smartperfetto.py
│   ├── validate_catalog.py
│   ├── validate_links.py
│   └── install.py
├── tests/
│   ├── fixtures/
│   ├── unit/
│   └── integration/
└── docs/
    ├── architecture.md
    ├── compatibility.md
    ├── migration-coverage.md
    └── superpowers/
```

### Workflow taxonomy

The router covers the current product surface through these workflow families:

1. trace sanity, schema discovery, process/thread identity, and time ranges;
2. startup and application lifecycle;
3. scrolling, frame production, jank, and rendering latency;
4. click, touch, input dispatch, and navigation response;
5. ANR, blocking chains, Binder, locks, futex, and scheduler latency;
6. CPU utilization, topology, frequency, idle, IRQ, and profiling;
7. memory, GC, heap graphs, LMK, DMA-BUF, RSS, and native allocation;
8. GPU, SurfaceFlinger, fences, VRR, thermal, and power;
9. IO, filesystem, block pressure, network, modem, media, and WebView;
10. games, Flutter, React Native, Compose, and vendor-specific signals;
11. rendering-pipeline detection and teaching for all current pipeline
    definitions;
12. single-trace scene reconstruction and dual/multi-trace comparison.

Each workflow has the same contract:

- activation and applicability;
- required inputs and trace signals;
- capability/schema probes;
- deterministic query sequence;
- evidence identifiers and typed result fields;
- interpretation limits and prohibited causal claims;
- no-data and unsupported-version behavior;
- optional deep-dive branches;
- final report requirements and provenance.

### Migration classification

Every current runtime candidate is recorded in
`catalog/smartperfetto-export.json` with source path, source hash, domain,
runtime type, public destination, and migration disposition.

- Root SQL and SQL-only atomic steps become named SQL assets plus metadata.
- Composite, iterator, conditional, parallel, and diagnostic definitions become
  workflow runbooks and deterministic runner plans.
- AI decision/summary steps become explicit agent instructions with evidence
  gates; deterministic data collection remains in scripts.
- Module Skills contribute domain knowledge, evidence schemas, and next-step
  decision rules.
- Pipeline definitions contribute detection/scoring rules, teaching diagrams,
  thread roles, key slices, and analysis recommendations. SmartPerfetto-only
  track pinning is documented as optional UI metadata and is not required.
- Comparison metadata becomes the public comparison workflow and report schema;
  SmartPerfetto snapshot services are replaced by file-based intermediate JSON.

No runtime candidate may silently disappear. A catalog entry must be either
`exported`, `merged` into another public workflow with a destination, or
`product-only` with a concrete reason. The validation gate fails on unclassified
sources.

## Portable Runtime

The Skill uses Python 3.11+ standard-library code and an external
`trace_processor_shell` executable. It never requires Node.js or SmartPerfetto.

Resolution order:

1. explicit `--trace-processor` argument;
2. `PERFETTO_TRACE_PROCESSOR` environment variable;
3. `trace_processor_shell` on `PATH`;
4. repository-managed cache populated by the bootstrap script.

The repository does not commit trace processor binaries. A lock file records
the supported official prebuilt URLs, platform/architecture mapping, version or
commit identifier, size, and SHA-256. Bootstrap downloads to a user cache,
verifies the hash before installation, and reports unsupported platforms
without falling back to an unverified binary.

`perfetto_probe.py` inspects metadata, available tables/modules, Android version,
trace bounds, and relevant data-source availability. `perfetto_query.py` runs
SQL files or inline queries with parameter binding performed by the wrapper,
bounded output, JSON/JSONL/CSV formats, timeout handling, and actionable errors.

Large or multi-step workflows write file-based JSON artifacts under a caller
selected output directory. This replaces SmartPerfetto's in-memory
DataEnvelope/session coupling while preserving trace identity, query source,
parameters, timestamps, units, and evidence provenance.

## Source-of-truth and Sync

SmartPerfetto remains authoritative for domain definitions. Perfetto-Skills
owns the portable templates, runner, public documentation, and generated export.

`tools/export_from_smartperfetto.py` accepts a SmartPerfetto checkout and:

1. discovers current runtime Skill candidates using repository rules;
2. reads the export manifest and source metadata;
3. normalizes supported YAML forms without importing SmartPerfetto services;
4. generates SQL assets, workflow evidence indexes, and pipeline references;
5. records source commit and content hashes;
6. refuses unknown step types, duplicate public identifiers, bad references,
   unclassified sources, or non-deterministic output ordering.

Generated paths carry a header and are never hand-edited. Curated workflow
instructions are checked against catalog destinations and source hashes. CI
regenerates from the pinned SmartPerfetto commit and requires a clean diff.

SmartPerfetto gains a small public-export manifest and documentation pointer;
it does not gain a second copy of generated `SKILL.md` content.

## Licensing

The initial public repository uses AGPL-3.0-or-later because the exported source
files already carry that SPDX identifier. Source notices and provenance remain
attached to generated assets. Any future move to a permissive license requires
an explicit copyright/relicensing decision and is outside this implementation.

Third-party Perfetto material retains its original notice and license. The
exporter distinguishes SmartPerfetto-authored content from upstream Perfetto
content so NOTICE and generated headers remain accurate.

## Distribution

The repository is public under the `Gracker` GitHub account. Installation is
supported by:

- cloning and running `python tools/install.py --client <name>`;
- copying `skills/perfetto-performance-analysis` into a supported client Skill
  directory;
- release archives containing the canonical Skill directory and checksums.

The installer supports Codex, Claude Code, OpenCode, and an explicit custom
destination. It defaults to copy mode, refuses destructive overwrite without
`--force`, and prints the installed source commit and validation command.

## Verification

Required gates:

1. open Agent Skills schema validation with `skills-ref`;
2. Python unit tests for runtime resolution, downloads, hash verification,
   parameter handling, exporter normalization, catalog coverage, link checking,
   and installation paths;
3. deterministic regeneration with no diff;
4. static validation of every exported SQL asset and workflow reference;
5. real trace processor smoke tests on representative trace fixtures;
6. end-to-end startup, scrolling, pipeline, and comparison workflows;
7. discovery smoke tests for Codex, Claude Code, and OpenCode layouts;
8. license/NOTICE and generated-file provenance checks;
9. clean `git diff --check` and a read-only independent architecture review;
10. GitHub repository visibility, default branch, pushed commit, and README
    installation commands verified from a fresh clone.

## Risks and Mitigations

- **Catalog scale:** use progressive disclosure and one router instead of 230
  top-level descriptions.
- **SQL schema drift:** probe before query, pin a tested trace processor, keep
  fallbacks explicit, and never interpret absent data as proof of absence.
- **Generated/curated divergence:** source hashes, catalog destinations,
  deterministic generation, and CI clean-diff checks.
- **Runtime portability:** no committed binaries; verified official downloads
  plus explicit local override.
- **False causal claims:** preserve evidence/claim boundaries from current
  strategies and require provenance in every report.
- **SmartPerfetto product coupling:** adapters are optional and all required
  workflows operate with local files and `trace_processor_shell` alone.

## Completion Criteria

The project is complete only when:

- `Gracker/Perfetto-Skills` exists publicly and a fresh clone succeeds;
- the standard Skill validates and is installable for the supported clients;
- every SmartPerfetto runtime Skill candidate is classified and covered;
- all workflow families above have executable or explicitly bounded public
  runbooks and referenced evidence assets;
- pipeline and comparison content works without SmartPerfetto services;
- the portable runtime passes unit and real-trace integration tests;
- regeneration from the pinned SmartPerfetto source is deterministic;
- SmartPerfetto documentation points to the public project and does not claim
  that standard Skills need not be migrated;
- repository validation, independent review, and fresh-clone smoke tests pass.
