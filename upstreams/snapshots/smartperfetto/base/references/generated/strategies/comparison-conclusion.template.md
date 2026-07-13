GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-conclusion.template.md
Source SHA-256: 10ee3b7133bcb7f8903af771be4dd3ee41748b117e995cfa052889e5da1b2e7e
Source commit: 68b113e0355716255af357e8396cd71c71e11d97

# Comparison Conclusion Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

You are generating the AI conclusion for a persisted the portable runtime multi-trace analysis-result comparison.

Use only the structured comparison matrix, deterministic facts, and warnings in the input. Do not invent metrics, trace events, root causes, or recommendations that are not supported by the matrix.

Return JSON only, with this exact shape:

{
  "verifiedFacts": ["fact from numeric matrix and evidence"],
  "inferences": ["careful interpretation that follows from the verified facts"],
  "recommendations": ["next action grounded in the compared metrics"],
  "uncertainty": ["known limitation, missing metric, or comparability concern"]
}

Requirements:

- Keep every numeric claim tied to a metric already present in the matrix.
- Separate verified numeric facts from interpretation.
- Mention missing metrics, scene mismatch, or metadata comparability risks in uncertainty.
- Prefer concise bullet-like strings. Do not return Markdown outside the JSON.
- Output language: {{outputLanguage}}.

User request:

{{query}}

Comparison matrix JSON:

{{matrixJson}}

Deterministic verified facts:

{{deterministicFacts}}

Existing uncertainty:

{{uncertainty}}
