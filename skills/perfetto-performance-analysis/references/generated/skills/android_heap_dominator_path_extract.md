GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/android_heap_dominator_path_extract.skill.yaml
Source SHA-256: de4b9f64860789167409e6604441d8c932167169e8bed9c34ff6cbd580dc0daf
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Android Heap Dominator Path Extract

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_heap_dominator_path_extract
version: '1.0'
type: composite
category: memory
tier: B
```

## Metadata

```yaml
display_name: Android Heap Dominator Path Extract
description: Extract bounded per-dump dominator class paths with propagated root identity and retained size
icon: memory
tags:
- memory
- heap_graph
- dominator
- retained_size
- batch
- upstream
```

## Triggers

```yaml
keywords:
  zh:
  - heap dominator path
  - 堆支配路径
  - 跨 trace 内存聚类
  - 保留路径
  en:
  - heap dominator path
  - heap path clustering
  - retained path
  - cross trace heap
patterns:
- .*(dominator|retained).*(path|cluster).*
- .*(支配|保留).*(路径|聚类).*
```

## Prerequisites

```yaml
modules:
- android.memory.heap_graph.dominator_class_tree
- graphs.scan
- graphs.hierarchy
```

## Inputs

```yaml
- name: upid
  type: integer
  required: false
  description: Optional stable process identity
- name: process_name
  type: string
  required: false
  description: Optional process name substring
- name: graph_sample_ts
  type: timestamp
  required: false
  description: Optional heap dump sample timestamp
- name: max_rows
  type: integer
  required: false
  default: 500
  description: Maximum dominator rows returned per trace, clamped to 500
```

## Ordered execution

### Heap graph availability

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/android_heap_dominator_path_extract/data_check.sql`](../sql/android_heap_dominator_path_extract/data_check.sql)

```yaml
id: data_check
type: atomic
display:
  level: key
  layer: overview
  title: Heap Graph Availability
  columns:
  - name: sample_count
    label: Heap Samples
    type: number
  - name: object_count
    label: Heap Objects
    type: number
  - name: status
    label: Status
    type: string
save_as: data_check
```
### Bounded dominator paths

- ID: `dominator_paths`
- Type: `atomic`
- SQL: [`../sql/android_heap_dominator_path_extract/dominator_paths.sql`](../sql/android_heap_dominator_path_extract/dominator_paths.sql)

```yaml
id: dominator_paths
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Heap Dominator Paths
  columns:
  - name: upid
    label: UPID
    type: number
  - name: process_name
    label: Process
    type: string
  - name: graph_sample_ts
    label: Heap Sample
    type: timestamp
    unit: ns
  - name: path
    label: Dominator Path
    type: string
  - name: class_name
    label: Class
    type: string
  - name: root_type
    label: Root Type
    type: string
  - name: self_count
    label: Self Count
    type: number
  - name: retained_count
    label: Retained Count
    type: number
  - name: self_size_bytes
    label: Self Size
    type: bytes
  - name: retained_size_bytes
    label: Retained Size
    type: bytes
save_as: dominator_paths
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: data_check
  description: Heap graph sample and object availability; zero means unavailable evidence, not absence of a leak
- name: dominator_paths
  description: Bounded per-(upid, graph_sample_ts) dominator paths with propagated root and cumulative retained size
```
