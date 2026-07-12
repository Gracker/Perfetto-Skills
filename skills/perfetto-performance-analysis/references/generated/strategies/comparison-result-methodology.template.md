GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/comparison-result-methodology.template.md
Source SHA-256: 7e90c0a2fb309eaabb079e038748338fad67cd988bdff2fc82ad2bcd48780732
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

# Comparison Result Methodology Template

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

## 分析结果对比方法论

### 输入确认

### Matrix First

1. 先构造 `ComparisonMatrix`，再生成解释。
2. 定量结论只引用 normalized metric：metric key、value、unit、source、confidence、evidence refs。
3. delta 只在 baseline 与 candidate 双方都有值时计算。
4. 缺失值必须保留在 missing matrix 中，不要用 0 或空字符串代替。

### 回填边界

1. snapshot 已有值时不要重新查询 Trace。
2. 标准 metric 缺失且 `allowTraceBackfill=true` 时，可以用 TraceProcessorLease 回填。
3. 回填失败不应中断 comparison run；把失败原因写入 uncertainty。
4. 自定义 metric 只有在有 extractor 或已存在 snapshot metric 时才可定量比较。

### 输出要求

- 先给 delta 表，再给显著变化。
- 每个关键结论拆成“已验证事实”和“推断”。
- 对不同 scene、不同设备、不同采集配置明确标注不可比风险。
- 每个优化建议必须指向一个已验证事实或显著变化。
- 不从旧报告正文或聊天记录中重新抽取数值。
