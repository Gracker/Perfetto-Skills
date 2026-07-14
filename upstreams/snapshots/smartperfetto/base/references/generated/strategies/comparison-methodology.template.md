GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-methodology.template.md
Source SHA-256: 504450e6dc153aee444a0915d50b996a51afe84c809efe2db28b61f1800a60a7
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

# Comparison Methodology Template

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

## 对比分析方法论

当两个 Trace 同时可用时，遵循以下结构化对比流程：

### Phase 4: 结构化结论
输出格式：

1. **Delta 表格**（必须）：
| 指标 | 当前 Trace | 参考 Trace | 变化 | 评估 |
|------|-----------|-----------|------|------|

2. **根因分析**：解释主要差异的根本原因
3. **建议**：基于对比结果的优化建议

### 约束
- 所有数值必须标注归一化方式（绝对值 / 百分比变化 / 占总时长比例）
- 不要对比单侧缺失的数据 — 在 delta 表中标注 "N/A"
- 每个数据引用必须标注来源：`[当前 Trace]` / `[参考 Trace]`，如果有窗口映射则写成 `[左侧/当前 Trace]`、`[右侧/参考 Trace]` 或对应的上/下侧标签
