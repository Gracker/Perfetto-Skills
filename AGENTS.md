# Perfetto Skills Agent Guide

Perfetto Skills is the portable Agent Skills projection of SmartPerfetto's
Perfetto analysis knowledge. Reply to maintainers in the language they use.

## Source boundaries

- SmartPerfetto `backend/skills/`, selected `backend/strategies/`, and
  `docs/rendering_pipelines/` remain the domain source of truth.
- Files marked `GENERATED FILE` are output. Fix the exporter or SmartPerfetto
  source and regenerate; never patch generated output directly.
- The public Skill must work without SmartPerfetto services, MCP, DataEnvelope,
  provider runtimes, session state, reports, snapshots, or UI actions.
- Do not commit trace processor binaries, credentials, proprietary traces, or
  unbounded query results.

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

## Development

Use Python 3.11+ and write a failing test before behavior changes.

```bash
uv sync --extra dev
uv run python tools/verify.py --smartperfetto ../SmartPerfetto
```

Only this repository-defined command may be used as the complete gate. If the
SmartPerfetto checkout is unavailable, run `uv run python tools/verify.py` and
report source/export and real-trace verification as unavailable rather than
claiming completion.
