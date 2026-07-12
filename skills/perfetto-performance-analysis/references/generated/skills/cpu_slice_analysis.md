GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_slice_analysis.skill.yaml
Source SHA-256: 2309b7c7da0ad9c74d1d781a1b5d0ea4b1466bc6f0ebd8757a467d36a7a59853
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# CPU Slice 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_slice_analysis
version: '2.0'
type: composite
category: hardware
tier: B
```

## Metadata

```yaml
display_name: CPU Slice 分析
description: 分析 CPU 时间片分布（动态拓扑检测）
icon: pie_chart
tags:
- cpu
- slice
- distribution
- composite
```

## Prerequisites

```yaml
required_tables:
- sched_slice
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 开始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 结束时间戳(ns，可选)
- name: package
  type: string
  required: false
  description: 应用包名（可选）
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
### CPU 时间片分布

- ID: `cpu_time_by_core`
- Type: `atomic`
- SQL: [`../sql/cpu_slice_analysis/cpu_time_by_core.sql`](../sql/cpu_slice_analysis/cpu_time_by_core.sql)

```yaml
id: cpu_time_by_core
type: atomic
display:
  level: detail
  format: table
  columns:
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: total_cpu_ms
    label: CPU时间
    type: duration
    format: duration_ms
  - name: big_core_ms
    label: 大核时间
    type: duration
    format: duration_ms
  - name: little_core_ms
    label: 小核时间
    type: duration
    format: duration_ms
  - name: slice_count
    label: 切片数
    type: number
    format: compact
  - name: avg_slice_ms
    label: 平均切片
    type: duration
    format: duration_ms
```
## Output and evidence contract

```yaml
format: structured
```
