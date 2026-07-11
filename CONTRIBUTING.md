# Contributing

Perfetto Skills keeps SmartPerfetto as the domain source of truth and generates
portable references from a pinned source commit.

## Before changing analysis content

1. Make the domain change in SmartPerfetto's validated YAML Skill, strategy, or
   rendering-pipeline source.
2. Update SmartPerfetto's public export policy when a new runtime Skill is
   added or its workflow ownership changes.
3. Regenerate this repository from the SmartPerfetto checkout.
4. Edit only curated workflow instructions and runtime tooling by hand; never
   hand-edit files marked `GENERATED FILE`.
5. Run the complete repository gate.

```bash
uv sync --extra dev
uv run python tools/verify.py --smartperfetto ../SmartPerfetto
```

Changes should include a failing test before implementation when behavior is
added or corrected. Keep the main `SKILL.md` concise and place detailed domain
knowledge in directly linked references.

