GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_cluster_mapping_view.skill.yaml
Source SHA-256: c5d603b71661230ea7d4c4b626a8e6e9d6ecb6844f83d8d215feb9429bf19fb1
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# CPU 大小核映射

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_cluster_mapping_view
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: CPU 大小核映射
description: CPU 编号 → cluster 类型映射
icon: view_module
tags:
- cpu
- cluster
- big_little
- topology
- atomic
```

## Prerequisites

```yaml
modules:
- android.cpu.cluster_type
```

## Ordered execution

### CPU Cluster 映射

- ID: `cluster_mapping`
- Type: `atomic`
- SQL: [`../sql/cpu_cluster_mapping_view/cluster_mapping.sql`](../sql/cpu_cluster_mapping_view/cluster_mapping.sql)

```yaml
id: cluster_mapping
type: atomic
display:
  level: detail
  layer: list
  title: CPU 拓扑（大小核）
  columns:
  - name: cpu
    label: CPU
    type: number
  - name: cluster_type
    label: Cluster
    type: string
```
