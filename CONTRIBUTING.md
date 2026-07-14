# Contributing

Perfetto Skills develops independently while importing selected SmartPerfetto
analysis knowledge and official Perfetto substrate through pinned, explicit
sync workflows.

## Before changing analysis content

1. Decide whether the change is native Perfetto-Skills work, a reviewed local
   overlay, or a SmartPerfetto import.
2. Add a failing project-owned real-trace assertion before changing local SQL.
3. Never hand-edit files marked `GENERATED FILE`; use the base/compiler/overlay
   workflow in `docs/maintenance/upstream-sync.md`.
4. Run the cross-repository impact checker and record its decision.
5. Run the complete independent gate.

```bash
uv sync --extra dev
uv run python tools/verify.py
```

Changes should include a failing test before implementation when behavior is
added or corrected. Keep the main `SKILL.md` concise and place detailed domain
knowledge in directly linked references.
