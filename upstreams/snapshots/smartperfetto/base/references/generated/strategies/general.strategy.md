GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/general.strategy.md
Source SHA-256: ee8e41f175846136b1af81f0467bb8ebdada0a34a5941b3df53293ea8730ba03
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a

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


<!-- strategy-detail id="full" title="general full strategy detail" keywords="general,通用分析,detail,full" default="true" -->
#### 通用分析

当前查询未匹配到特定场景策略。请根据用户关注的方向，使用以下决策树选择合适的分析路径。

**决策树 — 按用户关注方向路由：**

#### 通用场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`slice_self_dur`、`cpu_utilization_in_interval(ts, dur)`、`cpu_frequency_counters`、`android_garbage_collection_events`、`android_oom_adj_intervals`、`android_screen_state`、`android_dvfs_counters`、`wattson_rails_aggregation`、`android_battery_charge`
<!-- /strategy-detail -->
