GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_topology_detection.skill.yaml
Source SHA-256: 539074112cd1527ea174f211bee7834c523e137e7c052281ce81e1a3832ca6d0
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# CPU 拓扑检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_topology_detection
version: '1.0'
type: composite
category: hardware
tier: B
```

## Metadata

```yaml
display_name: CPU 拓扑检测
description: 基于共享 _cpu_topology 视图检测 CPU 大小核拓扑
icon: memory
tags:
- cpu
- topology
- cluster
- atomic
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间（保留兼容；共享拓扑检测使用整条 trace 的观测证据）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间（保留兼容；共享拓扑检测使用整条 trace 的观测证据）
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
### 检测 CPU 集群

- ID: `detect_cpu_clusters`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_detection/detect_cpu_clusters.sql`](../sql/cpu_topology_detection/detect_cpu_clusters.sql)

```yaml
id: detect_cpu_clusters
type: atomic
display:
  level: summary
  layer: overview
  title: CPU 拓扑检测结果
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: cluster_type
    label: 核心类型
    type: string
  - name: max_freq_mhz
    label: Max Freq
    type: number
  - name: capacity
    label: Capacity
    type: number
  - name: topology_source
    label: 判定来源
    type: string
  - name: cluster_rank
    label: 簇档位
    type: number
  - name: cluster_count
    label: 簇数量
    type: number
save_as: cpu_clusters
```
### 集群汇总

- ID: `cluster_summary`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_detection/cluster_summary.sql`](../sql/cpu_topology_detection/cluster_summary.sql)

```yaml
id: cluster_summary
type: atomic
display:
  level: summary
  layer: overview
  title: CPU 集群汇总
  columns:
  - name: cluster_type
    label: 核心类型
    type: string
  - name: cpu_count
    label: CPU 数
    type: number
  - name: cpus
    label: CPU 列表
    type: string
  - name: max_freq_mhz
    label: 最高频率
    type: number
  - name: min_freq_mhz
    label: 最低频率
    type: number
  - name: topology_source
    label: 判定来源
    type: string
save_as: cluster_summary
```
### 集群映射

- ID: `cluster_mapping`
- Type: `atomic`
- SQL: [`../sql/cpu_topology_detection/cluster_mapping.sql`](../sql/cpu_topology_detection/cluster_mapping.sql)

```yaml
id: cluster_mapping
type: atomic
save_as: cluster_mapping
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: cpu_clusters
  description: 每个 CPU 核心的集群类型
- name: cluster_summary
  description: 集群汇总（每种类型的核心数）
- name: cluster_mapping
  description: 集群映射表（供其他 skill 使用）
```
