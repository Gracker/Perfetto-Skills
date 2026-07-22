GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/general.strategy.md
Source SHA-256: 55e68c199e703ddf8070d9fecdbdb4019605b393811b5b2db6c9427ab54c9fd8
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

# General Strategy

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
scene: general
priority: 99
effort: high
required_capabilities:
- cpu_scheduling
optional_capabilities: []
keywords: []
```

#### general Core Strategy

**Route card**: general

**Capabilities**: required=[cpu_scheduling], optional=[none]

**Phase reminders**
- 无额外 phase hint。

**Final report contract summary**
- 遵循通用输出契约。
- 以下结构化区块是开放式分析收口行为的事实源：

```json analysis-closure-contract
{
  "applies_to": "open_ended_investigation",
  "max_secondary_domains": 3,
  "report_fields": [
    "checked_domains",
    "missing_data",
    "unresolved_alternatives"
  ],
  "skip_for": "bounded_question",
  "stop_conditions": [
    "no_independent_high_impact_anomaly",
    "repeated_evidence",
    "missing_data",
    "budget_exhausted"
  ]
}
```

- 对“全面分析”“为什么慢”等开放式请求，在主证据链成立后执行一次**有界次要瓶颈收口**：仅从已观测且仍有可用证据的方向中，最多检查 3 个尚未覆盖的独立域；遇到没有高影响独立异常、下一查询会重复已有证据、所需数据不可用或预算耗尽时立即停止。
- 对具体且范围明确的问题不附加该收口。最终报告列出已检查域、未解决的替代解释与缺失数据；次要检查为空不能削弱已经验证的主结论。


<!-- strategy-detail id="full" title="general full strategy detail" keywords="general,通用分析,detail,full" default="true" -->
#### 通用分析

当前查询未匹配到特定场景策略。请根据用户关注的方向，使用以下决策树选择合适的分析路径。

**决策树 — 按用户关注方向路由：**

#### 通用场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`slice_self_dur`、`cpu_utilization_in_interval(ts, dur)`、`cpu_frequency_counters`、`android_garbage_collection_events`、`android_oom_adj_intervals`、`android_screen_state`、`android_dvfs_counters`、`wattson_rails_aggregation`、`android_battery_charge`
<!-- /strategy-detail -->
