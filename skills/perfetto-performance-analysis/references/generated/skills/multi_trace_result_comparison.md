GENERATED FILE - DO NOT EDIT.
Source: backend/skills/comparison/multi_trace_result_comparison.skill.yaml
Source SHA-256: 8ceebdf45342707a08e64b6e35d6fa272180c18e1c92d077f10b6a2c8507abc1

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
