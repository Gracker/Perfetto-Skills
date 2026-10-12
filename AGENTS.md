# Perfetto Skills Agent Guide

Perfetto Skills is an independent, portable Agent Skill. Reply in the
maintainer's language. Inspect current source, tests, and worktree before
editing; preserve unrelated changes and review the task-owned diff before
landing.

## Source and evidence boundaries

- `src/` owns native behavior and reviewed overlays. Pinned SmartPerfetto
  snapshots own imported assets only. A sibling checkout is an explicit sync
  input, never a development or runtime dependency.
- Files marked `GENERATED FILE` are output: fix the exporter, immutable import,
  native source, or overlay and recompile. Never patch generated output.
- Public Skills must run without SmartPerfetto services, MCP, DataEnvelope,
  providers, sessions, reports, snapshots, or UI actions.
- Preserve missing-evidence, identity, timestamps, durations, units, trace-side,
  and claim-verification contracts. Do not commit processor binaries,
  credentials, proprietary traces, or unbounded query results.

## Skill layout

Keep the main `SKILL.md` under 500 lines with imperative instructions and
frontmatter at byte zero, accepted by both `quick_validate.py` and
`agentskills`. Put detail in `references/`, deterministic operations in
`scripts/`, templates in `assets/`, and optional UI metadata in
`agents/openai.yaml`.

## Verification and landing

Use Python 3.11+ and `uv sync --extra dev`. For iteration, choose the smallest
applicable repository check from [verification](docs/maintenance/verification.md).
Behavior fixes need focused regression coverage; local SQL changes need a
failing owned real-trace assertion. Documentation-only changes do not need an
artificial failing test. Before push, run the complete independent gate:

```bash
uv run python tools/verify.py
```

Scoped tiers, selected tests, and offline smoke are not a complete gate. Review
cross-repository impact before committing or pushing portable-behavior changes:

```bash
uv run python tools/check_cross_repo_impact.py --repository perfetto-skills \
  --base "$(git merge-base HEAD origin/main)"
```

Record `required`, `not_required`, or `deferred` with reason and fingerprint;
`deferred` needs a durable handoff. A required pairing must use the paired
checkout's exact immutable HEAD and pass both projects' gates before landing.
Trigger paths, evidence fields, pinned sync procedures, and overlay maintenance
are defined in [upstream synchronization](docs/maintenance/upstream-sync.md).
Do not mechanically copy local overlays upstream.
