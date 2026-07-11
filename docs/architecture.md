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
  knowledge, and rendering-pipeline documents.
- `scripts/`: local trace-processor bootstrap, probe, and query CLIs.

SmartPerfetto runtime services are deliberately absent. Provider selection,
session state, product artifacts, DataEnvelope rendering, streaming, reports,
snapshots, and frontend behavior remain in the product repository.

## Analysis flow

1. The client discovers `perfetto-performance-analysis` from `SKILL.md`.
2. The router records trace identity and loads the evidence contract.
3. `perfetto_probe.py` establishes trace bounds, tables, metadata, and broad
   capability availability.
4. The agent selects one workflow from `workflow-index.json`.
5. The workflow links only the generated definitions and SQL needed for the
   question. The agent executes queries through `perfetto_query.py` and saves
   source, parameters, units, identity, interval, and row bounds.
6. Findings climb from observation to correlation, mechanism evidence, and
   verified root cause. Reports follow `assets/report-schema.json`.
7. Multi-trace work repeats steps 2-6 independently for every side before any
   delta or causal attribution.

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

The query CLI passes the executable, query file, and trace as an argument array,
enforces timeouts, and returns typed JSON/CSV/raw results. Empty rows remain
distinct from unavailable instrumentation and query failure.
