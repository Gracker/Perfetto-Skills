GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_topology_view.skill.yaml
Source SHA-256: 1a730191dd48abb10a07b8d4b95200f4d4b160ae178d037907613bef58910630
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# CPU 拓扑视图初始化

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_topology_view
version: '1.0'
type: composite
category: hardware
tier: B
```

## Metadata

```yaml
display_name: CPU 拓扑视图初始化
description: 创建 CPU 拓扑分类视图，供后续 SQL JOIN 使用
icon: memory
tags:
- cpu
- topology
- cluster
- view
- atomic
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间（可选，用于 cpufreq 回退检测）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间（可选，用于 cpufreq 回退检测）
```

## Ordered execution

### 清理旧 CPU 拓扑视图

- ID: `drop_existing_topology_view`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_view/drop_existing_topology_view.sql`](../sql/cpu_topology_view/drop_existing_topology_view.sql)

```yaml
id: drop_existing_topology_view
type: atomic
optional: true
display:
  level: hidden
```
### 创建 CPU 拓扑视图

- ID: `create_topology_view`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_view/create_topology_view.sql`](../sql/cpu_topology_view/create_topology_view.sql)

```yaml
id: create_topology_view
type: atomic
optional: true
display:
  level: hidden
```
### 读取 CPU 拓扑

- ID: `read_topology`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_view/read_topology.sql`](../sql/cpu_topology_view/read_topology.sql)

```yaml
id: read_topology
type: atomic
display:
  level: summary
  layer: overview
  title: CPU 拓扑
  columns:
  - name: cpu_id
    label: CPU
    type: number
  - name: capacity
    label: Capacity
    type: number
  - name: universe_source
    label: CPU 来源
    type: string
  - name: max_freq_mhz
    label: Max Freq
    type: number
  - name: scale_bucket
    label: Scale Bucket
    type: number
  - name: core_type
    label: 核心类型
    type: string
  - name: topology_source
    label: 判定来源
    type: string
  - name: cluster_rank
    label: 簇档位
    type: number
  - name: cluster_count
    label: 簇数量
    type: number
save_as: cpu_topology
optional: true
```
## Output and evidence contract

```yaml
format: structured
```
