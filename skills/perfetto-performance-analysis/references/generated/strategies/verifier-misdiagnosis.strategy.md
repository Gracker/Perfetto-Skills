GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/verifier-misdiagnosis.strategy.md
Source SHA-256: 7489962fb5e4c477d39cf811c2f57e201458635d9d3163bcaee144a2bc513761
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

# Verifier Misdiagnosis Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: verifier_misdiagnosis
strategy_kind: contract_only
priority: 99
effort: low
keywords: []
verifier_misdiagnosis_patterns:
- id: vsync_vrr_alignment_false_positive
  type: known_misdiagnosis
  scenes:
  - pipeline
  - touch_tracking
  - scrolling
  - scroll_response
  - interaction
  severity: warning
  patterns:
  - VSync.*(?:对齐异常|misalign|偏移)
  message: VSync 对齐异常可能是正常的 VRR (可变刷新率) 行为，需确认设备是否支持 VRR
- id: buffer_stuffing_not_app_jank
  type: known_misdiagnosis
  scenes:
  - scrolling
  - pipeline
  severity: warning
  patterns:
  - Buffer Stuffing.*(?:严重|critical|掉帧)
  message: Buffer Stuffing 是管线背压问题，非 App 逻辑缺陷 — 感知掉帧率已排除 Buffer Stuffing，请勿将其等同于真实掉帧
- id: single_frame_critical_false_positive
  type: known_misdiagnosis
  global: true
  severity: warning
  patterns:
  - (?:单帧|single frame|1帧).*(?:异常|critical|严重)
  message: 单帧异常不应标记为 CRITICAL — 需确认是否有模式性重复
```

Verifier misdiagnosis guardrail contracts. This file is data-only and is not
injected into runtime prompts.
