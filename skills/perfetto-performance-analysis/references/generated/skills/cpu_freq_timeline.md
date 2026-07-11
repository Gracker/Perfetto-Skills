GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_freq_timeline.skill.yaml
Source SHA-256: 1e522ca6fb183f6510f044547c8d5f97b82b8de7b181ceeae96795b0b1e8fe84
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# CPU 频率变化时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_freq_timeline
version: '2.0'
type: composite
category: hardware
tier: B
```

## Metadata

```yaml
display_name: CPU 频率变化时间线
description: 分析指定时间范围内各 CPU 核心的频率变化
icon: speed
tags:
- cpu
- frequency
- timeline
- composite
```

## Prerequisites

```yaml
required_tables:
- cpu_counter_track
- counter
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 开始时间戳 (纳秒)
- name: end_ts
  type: timestamp
  required: true
  description: 结束时间戳 (纳秒)
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
### CPU 频率变化

- ID: `cpu_freq_changes`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_timeline/cpu_freq_changes.sql`](../sql/cpu_freq_timeline/cpu_freq_changes.sql)

```yaml
id: cpu_freq_changes
type: atomic
display: false
save_as: freq_changes
```
### CPU 频率汇总

- ID: `cpu_freq_summary`
- Type: `atomic`
- SQL: [`../sql/cpu_freq_timeline/cpu_freq_summary.sql`](../sql/cpu_freq_timeline/cpu_freq_summary.sql)

```yaml
id: cpu_freq_summary
type: atomic
display:
  level: summary
  title: 频率汇总
  columns:
  - name: core_type
    label: 核心类型
    type: string
  - name: cpu_count
    label: 核心数
    type: number
  - name: avg_freq_mhz
    label: 平均频率
    type: number
  - name: max_freq_mhz
    label: 最大频率
    type: number
  - name: min_freq_mhz
    label: 最小频率
    type: number
  - name: freq_changes
    label: 频率变化次数
    type: number
    format: compact
  - name: downclocks
    label: 降频次数
    type: number
    format: compact
save_as: freq_summary
```
## Output and evidence contract

```yaml
format: structured
```
