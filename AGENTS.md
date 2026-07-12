# Perfetto Skills Agent Guide

Perfetto Skills is an independently developed, portable Agent Skill for
Perfetto analysis. It synchronizes selected knowledge from SmartPerfetto and
official Perfetto through explicit, pinned workflows. Reply to maintainers in
the language they use.

## Source boundaries

- The pinned SmartPerfetto snapshot is the source of truth only for imported
  assets. Perfetto-Skills-native behavior and reviewed overlays live under
  `src/` and evolve independently.
- Files marked `GENERATED FILE` are output. Fix the exporter, immutable import,
  native source, or explicit overlay and recompile; never patch generated
  output directly.
- The public Skill must work without SmartPerfetto services, MCP, DataEnvelope,
  provider runtimes, session state, reports, snapshots, or UI actions.
- Do not commit trace processor binaries, credentials, proprietary traces, or
  unbounded query results.
- Normal development and verification use this repository's owned real-trace
  fixtures. A sibling SmartPerfetto checkout is only an explicit sync input.

## Skill rules

- Keep `skills/perfetto-performance-analysis/SKILL.md` under 500 lines and use
  imperative instructions.
- Frontmatter must begin at byte zero and remain accepted by both
  `quick_validate.py` and the `agentskills` validator from `skills-ref`.
- Put Agent-readable detail in `references/`, deterministic operations in
  `scripts/`, output templates in `assets/`, and optional Codex UI metadata in
  `agents/openai.yaml`.
- Preserve missing-evidence, identity, timestamp, duration, units, trace-side,
  and claim-verification boundaries.

## Cross-repository impact

Before committing or pushing a change that can alter portable Skill behavior,
run:

```bash
uv run python tools/check_cross_repo_impact.py --repository perfetto-skills \
  --base "$(git merge-base HEAD origin/main)"
```

The command includes branch, staged, unstaged, and untracked paths. For a
matched change, record exactly one semantic decision: `required`,
`not_required`, or `deferred`. Every decision needs a reason; `deferred` also
needs a durable handoff. If the decision is `required`, pass `--paired-path`
and an immutable `--paired-ref` equal to the paired checkout HEAD, update and
verify SmartPerfetto before landing, and record the emitted fingerprint/paired
evidence in commit or PR notes; otherwise use `deferred` with the tracking
location. Do not mechanically copy local overlays upstream.

The complete trigger list, paired checks, and SmartPerfetto, Google official
Skill, and PerfettoSQL synchronization procedures live in
`docs/maintenance/upstream-sync.md`.

## Development

Use Python 3.11+ and write a failing test before behavior changes.

```bash
uv sync --extra dev
uv run python tools/verify.py
```

Only this repository-defined command may be used as the complete gate. Use
`--offline` for the committed smoke trace and `--smartperfetto PATH` only for
an explicit synchronization check; neither is a substitute for the complete
independent gate before push.
