# Architecture

Perfetto Skills is one broad standard Agent Skill with a deterministic local
query runtime and progressively loaded references. This shape preserves the
Agent Skills discovery contract without publishing hundreds of overlapping
top-level trigger descriptions.

## Source relationship

SmartPerfetto owns the domain source of truth:

- `backend/skills/**/*.skill.yaml`: deterministic SQL and orchestration DSL.
- `backend/strategies/`: scene methodology, evidence rules, and knowledge.
- `docs/rendering_pipelines/`: architecture teaching and pipeline evidence.
- `backend/skills/public-export.yaml`: explicit public/product-only policy.

This repository owns the portable projection:

- `skills/perfetto-performance-analysis/SKILL.md`: standard router and operating
  contract.
- `references/workflows/`: 14 curated, standalone analysis runbooks.
- `references/evidence/` and `references/knowledge/`: portable evidence and
  interpretation boundaries.
- `references/generated/`: generated Skill references, SQL, strategies,
  knowledge, rendering-pipeline documents, and sharded runtime manifests.
- `scripts/`: local trace-processor bootstrap, release doctor, capability probe,
  deterministic Skill executor, query, comparison, and report CLIs.

SmartPerfetto runtime services are deliberately absent. Provider selection,
session state, product artifacts, DataEnvelope rendering, streaming, reports,
snapshots, and frontend behavior remain in the product repository.

## Analysis flow

1. The client discovers `perfetto-performance-analysis` from `SKILL.md`.
2. `perfetto_doctor.py` verifies the selected binary against the v57.2 commit,
   RPC API, platform, and SHA-256 release lock.
3. `perfetto_probe.py` establishes trace bounds and five-state capability
   evidence: unsupported, not recorded, recorded empty, recorded populated, or
   unknown.
4. The agent selects one workflow from `workflow-index.json` and invokes
   `perfetto_skill.py run` for its exported root Skill.
5. The executor lazily loads only the transitive Skill and SQL shards. It
   applies typed defaults, prerequisites, identity rules, safe conditions,
   persistent SQL setup dependencies, child Skills, bounded iterators,
   diagnostics, empty/error semantics, and explicit AI handoffs.
6. Every query emits stable evidence with trace, source, rendered SQL,
   validation, compatibility, and processor identity. The agent promotes those
   observations only through the evidence contract; reports are checked by
   `perfetto_report.py` against `assets/report-schema.json`.
7. Multi-trace work repeats the complete run independently for every side
   before `perfetto_compare.py` admits any metric delta or causal attribution.

## Generated-file contract

`tools/export_from_smartperfetto.py` consumes a clean SmartPerfetto checkout and
refuses unclassified sources, stale policy entries, duplicate names/paths,
unsafe destinations, unsupported step types, and SQL filename collisions. The
catalog records the source commit, policy hash, and every source file hash.

Normal generation writes into a temporary directory, normalizes text, and
atomically replaces `references/generated/` only after every entry renders.
`--check` regenerates a temporary manifest and rejects catalog, documentation,
or generated-file drift. Generated files must never be edited by hand.

## Runtime and trust boundary

The runtime is Python standard library code plus a separate
`trace_processor_shell`. It never invokes a shell string for queries. The
bootstrap selects the host entry from `trace-processor-lock.json`, downloads
over HTTPS, verifies SHA-256, marks the verified temporary file executable, and
atomically installs it in a user cache. No binary is committed to this
repository or release archive.

The Skill and manifest-query CLIs reject a processor whose commit, RPC API, or
SHA-256 differs from the release lock unless the caller supplies the explicit
`--allow-unsupported-processor` escape hatch. This is separate from
`--allow-unverified`, which applies only to queries explicitly classified as
unverified. Capability-gated queries instead require an automatic, same-trace
probe and preserve that gate result in their evidence sidecar.

The query CLI passes the executable, query, and trace as an argument array,
enforces timeouts and a default 16 MiB stdout/stderr bound, and returns typed
JSON/CSV/raw results. It safely binds scalar placeholders, JSON literal lists,
declared Perfetto modules, and non-empty JSON row arrays saved by prior steps.
The deterministic runner uses a validated, non-evaluating expression subset for
authored step conditions. Empty rows remain distinct from unavailable
instrumentation and query failure.

Product snapshot services are replaced by `perfetto_compare.py`. Each trace is
analyzed independently into a local side-summary JSON; the adapter compares
only metrics whose status, unit, and definition match, preserving evidence
references and typed limitations.
