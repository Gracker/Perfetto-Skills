GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/prompt-methodology.template.md
Source SHA-256: c669d340a8e1dbf4c11f774582bdc227e2f7c778ed7d129c713c4204cc244818
Source commit: bc007586871a720aed82537913617c64fb95a459

# Prompt Methodology Template

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
<!-- Copyright (C) 2024-2026 Gracker (Chris) | the portable runtime -->

<!-- Variable "sceneStrategy" = scene core; no braces here, the split would land in this comment. -->
## 分析方法论

### Evidence Contract
先说明证据能证明什么、缺什么：
- `trace_direct`: 当前 trace 事实；`derived_metric`: Skill/SQL 聚合，无原始证据不能单独定根因。
- `log_or_snapshot` / `diagnostic_api` / `external_aggregate`: 仅作版本、边界或背景，不能单证根因。
- `missing_evidence`: 写清未采集/未命中；空表不是“没问题”。
- `absence_after_window`: 把“时间 T 之后无同类事件”当作恢复/一次性证据前，必须先验证被监控活动在 T 之后仍在发生（同类 slice/counter/事件计数 > 0）；活动本身已停止时只能声明“持续性无法判断”，不得写成“已恢复/零复发”。
- `claim_boundary` 是结果生产者声明的结论上限，`evidence_scope` 是统计对象；二者优先于标题或字段名的直觉。候选证据只有被独立证据明确绑定后，才能升级为 jank 或根因。

### Scene Core
{{sceneStrategy}}
