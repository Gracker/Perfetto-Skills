GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-evidence-provenance.template.md
Source SHA-256: 2d9053f33f224f11f3c38086602477834282da9988d6df5a45ffb80320a2dff8
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

# Knowledge Evidence Provenance Template

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

## 证据来源与置信度边界

the portable runtime 报告应先说明证据能证明什么，再给根因和建议。常用证据类型：

- `trace_direct`：Perfetto 时间线、线程状态、帧、slice、Binder、I/O、功耗表等当前 trace 直接事实。适合支撑当前 trace 内的因果判断。
- `derived_metric`：Skill/SQL 聚合出的 TopN、分位、占比、诊断标签。适合定位方向，但需要可回溯的原始行或窗口支撑最终根因。
- `log_or_snapshot`：logcat、系统事件、业务日志、崩溃/ANR/exit/start 快照。适合提供语义和事件边界。
- `external_aggregate`：Play Vitals、APM、实验平台、App Performance Score。适合做线上背景或治理输入，不能替代当前 trace 证据。
- `diagnostic_api`：ApplicationExitInfo、ApplicationStartInfo、ProfilingManager/Trigger 等版本化诊断 API。必须带 Android/API/Extension 能力边界。
- `missing_evidence`：当前 trace 未采集、表为空、日志缺失、能力不支持。它只能降低置信度并指导下一步采集，不能作为排除问题的证据。

报告写法：

- 高置信：直接 trace/Skill 数据与日志或链路证据互相印证，并且窗口、进程、线程、版本边界明确。
- 中置信：有强指标或候选模式，但缺少 peer、owner、request-stage、heap/profile、rail 等关键补证。
- 低置信：只有外部聚合、用户描述、空表、缺失能力或间接推断。

边界原则：

- 单条 trace 可以证明这次采集窗口内的行为，不能直接证明 28 天 Play Vitals、A/B 因果或全量用户趋势。
- packet-level 网络数据不是 DNS/TCP/TLS/TTFB 阶段耗时；需要 request-level telemetry、OkHttp/Cronet events 或接入层日志补证。
- 短窗口 wakelock/功耗数据不是 24h Vitals 判定；只能写成局部窗口证据或换算参考。
- 版本敏感能力必须写明 Android/API/Extension 或“未知，需按目标设备确认”。
