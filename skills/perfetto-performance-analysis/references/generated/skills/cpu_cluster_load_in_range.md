GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_cluster_load_in_range.skill.yaml
Source SHA-256: 531fd3145d1a67a1ae02e1e028280f2e0e627b4bde1f7c832a985911391fd433
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# CPU 簇负载分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_cluster_load_in_range
version: '2.0'
type: composite
category: cpu
tier: B
```

## Metadata

```yaml
display_name: CPU 簇负载分析
description: 计算大核簇和小核簇的整体 CPU 负载百分比（动态拓扑检测）
icon: memory
tags:
- cpu
- cluster
- load
- atomic
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
### CPU 簇负载计算

- ID: `cluster_load`
- Type: `atomic`
- SQL: [`../sql/cpu_cluster_load_in_range/cluster_load.sql`](../sql/cpu_cluster_load_in_range/cluster_load.sql)

```yaml
id: cluster_load
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: CPU 簇负载
  columns:
  - name: cluster
    label: CPU 簇
    type: string
  - name: core_count
    label: 核心数
    type: number
  - name: running_ms
    label: Running 时间
    type: duration
    format: duration_ms
    unit: ms
  - name: total_capacity_ms
    label: 总容量
    type: duration
    format: duration_ms
    unit: ms
  - name: load_pct
    label: 负载
    type: percentage
    format: percentage
  - name: idle_pct
    label: 空闲
    type: percentage
    format: percentage
  - name: max_single_core_pct
    label: 最忙核心
    type: percentage
    format: percentage
save_as: cluster_load
```
## Output and evidence contract

```yaml
format: structured
```
