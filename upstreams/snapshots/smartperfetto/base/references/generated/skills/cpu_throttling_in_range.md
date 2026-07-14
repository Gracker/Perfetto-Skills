GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_throttling_in_range.skill.yaml
Source SHA-256: dfaad621766ab875e89c14795a27c2956c029bc84893cbabb175a44827fb001e
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
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
description: 检测 CPU 热控限频情况（动态拓扑检测）
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
  - name: throttle_detected
    label: 检测到限频
    type: boolean
save_as: throttle_data
```
## Output and evidence contract

```yaml
format: structured
```
