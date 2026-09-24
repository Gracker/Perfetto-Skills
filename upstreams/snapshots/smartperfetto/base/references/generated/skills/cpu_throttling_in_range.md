GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
Source SHA-256: 66ed6bab7c1a8f9703f90d803207fe45d9ff00e880e15bea97c75600f0568c39
Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df
# CPU 限频检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_throttling_in_range
version: '2.0'
type: composite
category: thermal
tier: B
```

## Metadata

```yaml
display_name: CPU 限频检测
description: 观测 CPU 频率变化；频率跨度不能独立证明热控限频
icon: thermostat
tags:
- cpu
- thermal
- throttling
- composite
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
```

## Ordered execution

### 限频证据

- ID: `limit_evidence`
- Type: `atomic`
- SQL: [`../sql/cpu_throttling_in_range/limit_evidence.sql`](../sql/cpu_throttling_in_range/limit_evidence.sql)

```yaml
id: limit_evidence
type: atomic
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_freq_limit_spans.sql
- fragments/system_cpu_freq_limit_episodes.sql
display:
  level: summary
  layer: overview
  title: 限频证据（cpufreq policy 上限）
  columns:
  - name: has_limit_track
    label: 有限频轨道
    type: boolean
  - name: episode_count
    label: 限频区段数
    type: number
  - name: policy_count
    label: 涉及 policy 数
    type: number
  - name: deepest_depth_pct
    label: 最大限频深度
    type: percentage
  - name: min_limit_khz
    label: 最低上限
    type: number
  - name: reference_max_limit_khz
    label: 参考上限
    type: number
  - name: reference_basis
    label: 参考依据
    type: string
  - name: evidence_status
    label: 证据状态
    type: string
  - name: next_step
    label: 下一步
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: limit_evidence
```
### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### 热控限频检测

- ID: `throttle_detection`
- Type: `atomic`
- SQL: [`../sql/cpu_throttling_in_range/throttle_detection.sql`](../sql/cpu_throttling_in_range/throttle_detection.sql)

```yaml
id: throttle_detection
type: atomic
process_scope:
  role: global_context
display:
  level: detail
  layer: deep
  title: 热控限频
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: start_freq_mhz
    label: 起始频率
    type: number
  - name: end_freq_mhz
    label: 结束频率
    type: number
  - name: min_freq_mhz
    label: 最低频率
    type: number
  - name: max_freq_mhz
    label: 最高频率
    type: number
  - name: freq_drop_pct
    label: 降幅
    type: percentage
    format: percentage
  - name: frequency_variation_detected
    label: 观测到频率变化
    type: boolean
  - name: evidence_status
    label: 热原因证据
    type: string
  - name: interpretation
    label: 解释
    type: string
  - name: throttle_detected
    label: 已核验热控限频
    type: boolean
save_as: throttle_data
```
## Output and evidence contract

```yaml
format: structured
```
