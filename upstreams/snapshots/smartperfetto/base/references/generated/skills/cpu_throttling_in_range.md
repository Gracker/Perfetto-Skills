GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
Source SHA-256: cb86c9d88cd71f79716c0e53b87ed34e4ef068e86e881f0bb0aca434f7a2a757
# CPU 限频检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_throttling_in_range
version: '2.1'
type: composite
category: thermal
tier: B
```

## Metadata

```yaml
display_name: CPU 限频检测
description: 观测 CPU 频率变化与 cpufreq 频率上限；频率跨度不能独立证明限频，限频本身也不说明是否由温控触发
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
  - name: has_max_limit_data
    label: 有有效上限样本
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
  - name: limit_evidence_missing_reason
    label: 缺失原因
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
### CPU 限频检测

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
  title: CPU 限频
  columns:
  - name: core_type
    label: 核心类别
    type: string
  - name: start_freq_mhz
    label: 窗口内首采样均值
    type: number
  - name: end_freq_mhz
    label: 窗口内末采样均值
    type: number
  - name: min_freq_mhz
    label: 类别最低频率
    type: number
  - name: max_freq_mhz
    label: 类别最高频率
    type: number
  - name: freq_drop_pct
    label: 单轨最大频率跨度
    type: percentage
    format: percentage
  - name: frequency_variation_detected
    label: 单轨跨度超 30%
    type: boolean
  - name: evidence_status
    label: 限频证据状态
    type: string
  - name: interpretation
    label: 解释
    type: string
  - name: throttle_detected
    label: 已观测 CPU 限频
    type: boolean
save_as: throttle_data
```
## Output and evidence contract

```yaml
format: structured
```
