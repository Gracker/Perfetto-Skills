GENERATED FILE - DO NOT EDIT.
Source: backend/skills/comparison/multi_trace_result_comparison.skill.yaml
Source SHA-256: 77585c59a25d4c89d4510b6d4017e3bd1d0e48dcd05e45064517414e5ec8a738
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

# File-based trace comparison

The SmartPerfetto source definition uses product snapshot services. The portable projection replaces that boundary with local JSON files and `scripts/perfetto_compare.py`.

## Inputs

Analyze every trace independently, then write one side summary that follows `assets/comparison-input-schema.json`. Each metric carries status, numeric value when observed, unit, exact definition, and evidence references.

## Execution

```bash
python3 <skill-root>/scripts/perfetto_compare.py \
  --side baseline=/absolute/baseline.json \
  --side candidate=/absolute/candidate.json \
  --baseline baseline --output /absolute/comparison.json
```

The adapter rejects duplicate sides and incompatible definitions, records missing metrics as limitations, and computes absolute/percent deltas only for comparable facts.
