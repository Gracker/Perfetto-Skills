GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_freq_limit_timeline.skill.yaml
Source SHA-256: 9ca20ae0bd75e18a790d8f725bc86549da9ef82647525a0180194ab11908877b
Source commit: e7ff73a937cc66d89fdc69d59728025734759acd
# CPU 限频时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_freq_limit_timeline
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: CPU 限频时间线
description: 从 cpufreq policy 限频轨道读取限频概览、去抖动限频区段与逐次限频变更事件
icon: speed
tags:
- cpu
- frequency
- limit
- cpufreq
- thermal
- evidence
```

## Triggers

```yaml
keywords:
  zh:
  - 限频时间线
  - 限频事件
  - 频率上限
  - cpufreq 限制
  en:
  - frequency limit timeline
  - cpufreq limit
  - max freq limit
patterns:
- .*(限频|频率上限).*(时间线|事件|区段).*
- .*cpufreq.*limit.*
```

## Prerequisites

```yaml
required_tables:
- cpu_counter_track
- counter
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；缺省使用观测数据起点
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)；缺省使用 trace 数据终点
- name: episode_drop_pct
  type: number
  required: false
  default: 10
  description: 判定限频区段的降幅阈值（相对本 trace 观测到的最大上限，%）
- name: merge_gap_ms
  type: number
  required: false
  default: 500
  description: 限频区段合并间隔（ms）；内核调控器高频改写上限，短间隔属同一次限频
```

## Ordered execution

### 限频数据检测

- ID: `limit_data_check`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_limit_timeline/limit_data_check.sql`](../sql/cpu_freq_limit_timeline/limit_data_check.sql)

```yaml
id: limit_data_check
type: atomic
process_scope:
  role: global_context
display: false
save_as: limit_data_check
```
### 限频概览

- ID: `limit_summary`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_limit_timeline/limit_summary.sql`](../sql/cpu_freq_limit_timeline/limit_summary.sql)

```yaml
id: limit_summary
type: atomic
condition: limit_data_check.data?.[0]?.has_max_limit_track === 1 || limit_data_check.data?.[0]?.has_min_limit_track === 1
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
display:
  level: summary
  layer: overview
  title: CPU 限频概览（按 cpufreq policy）
  columns:
  - name: window_id
    label: window_id
    type: number
    hidden: true
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_dur_ns
    label: 窗口时长
    type: duration
    unit: ns
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: ucpu
    label: ucpu
    type: number
    hidden: true
  - name: machine_id
    label: machine_id
    type: number
    hidden: true
  - name: core_type
    label: 核心类型
    type: string
  - name: topology_source
    label: 拓扑来源
    type: string
  - name: kind
    label: 限制类型
    type: string
  - name: avg_limit_khz
    label: 时间加权均值
    type: number
  - name: min_limit_khz
    label: 最低上限
    type: number
  - name: max_limit_khz
    label: 最高上限
    type: number
  - name: reference_max_limit_khz
    label: 参考上限
    type: number
  - name: reference_basis
    label: 参考依据
    type: string
  - name: sample_count
    label: 变更次数
    type: number
  - name: first_sample_ts
    label: 首个变更
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: last_sample_ts
    label: 最后变更
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: pre_first_sample_ns
    label: 首样本前未知时长
    type: duration
    unit: ns
  - name: first_sample_state_unknown
    label: 首样本前状态未知
    type: string
  - name: limit_covered_ns
    label: 限频覆盖
    type: duration
    unit: ns
  - name: limit_evidence
    label: 限频证据
    type: string
  - name: limit_source
    label: 数据来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: limit_summary
```
### 限频区段

- ID: `limit_episodes`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_limit_timeline/limit_episodes.sql`](../sql/cpu_freq_limit_timeline/limit_episodes.sql)

```yaml
id: limit_episodes
type: atomic
condition: limit_data_check.data?.[0]?.has_max_limit_track === 1
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
- fragments/system_cpu_freq_limit_episodes.sql
display:
  level: summary
  layer: list
  title: 限频区段（去抖动合并）
  columns:
  - name: episode_id
    label: 区段
    type: string
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: topology_source
    label: 拓扑来源
    type: string
  - name: episode_start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: episode_end_ts
    label: 结束
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: episode_dur_ns
    label: 持续
    type: duration
    unit: ns
  - name: min_limit_khz
    label: 最低上限
    type: number
  - name: reference_max_limit_khz
    label: 参考上限
    type: number
  - name: depth_pct
    label: 限频深度
    type: percentage
  - name: change_count
    label: 合并变更数
    type: number
  - name: starts_at_data_start
    label: 起点未知
    type: boolean
  - name: ends_at_data_end
    label: 终点未知
    type: boolean
  - name: evidence_status
    label: 证据状态
    type: string
  - name: reference_basis
    label: 参考依据
    type: string
  - name: thresholds
    label: 阈值
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有超过阈值的限频区段；可调低 episode_drop_pct 复查更浅的限频。
save_as: limit_episodes
```
### 限频变更事件

- ID: `limit_events`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_limit_timeline/limit_events.sql`](../sql/cpu_freq_limit_timeline/limit_events.sql)

```yaml
id: limit_events
type: atomic
condition: limit_data_check.data?.[0]?.has_max_limit_track === 1 || limit_data_check.data?.[0]?.has_min_limit_track === 1
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
display:
  level: detail
  layer: list
  title: 限频变更事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: policy_cpu
    label: policy 首核
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: kind
    label: 限制类型
    type: string
  - name: prev_limit_khz
    label: 变更前
    type: number
  - name: limit_khz
    label: 变更后
    type: number
  - name: delta_khz
    label: 变化量
    type: number
  - name: direction
    label: 方向
    type: string
  - name: dur_ns
    label: 保持时长
    type: duration
    unit: ns
  - name: reference_max_limit_khz
    label: 参考上限
    type: number
  - name: limit_source
    label: 数据来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有限频变更事件。
save_as: limit_events
```
### 限频数据不可用

- ID: `limit_unavailable`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_limit_timeline/limit_unavailable.sql`](../sql/cpu_freq_limit_timeline/limit_unavailable.sql)

```yaml
id: limit_unavailable
type: atomic
condition: limit_data_check.data?.[0]?.has_max_limit_track !== 1 && limit_data_check.data?.[0]?.has_min_limit_track !== 1
process_scope:
  role: global_context
display:
  level: summary
  layer: overview
  title: 限频数据不可用
  columns:
  - name: limit_evidence
    label: 限频证据
    type: string
  - name: required_ftrace_event
    label: 需要采集的 ftrace 事件
    type: string
  - name: message
    label: 说明
    type: string
save_as: limit_unavailable
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- limit_summary
- limit_episodes
```
