GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/android_heap_dominator_path_extract.skill.yaml
Source SHA-256: 79a6054d4d6744e18381baa97106c13e0a4e11f4c8655ba9ade28004904aab52
Source commit: 34565222fe4f57b64349758a76221c4144e5d09e
# Android Heap Dominator Path Extract

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_heap_dominator_path_extract
version: '1.1'
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
  description: Optional process name, exact or name:* subprocess (fragments/heap_target_process.sql); when nothing matches,
    dumps without a process name (e.g. .hprof) are used and flagged process_name_unavailable_upid_fallback
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
  - name: placeholder_object_count
    label: Placeholder Objects (self_size=-1)
    type: number
  - name: incomplete_dump_count
    label: Incomplete Dumps
    type: number
  - name: process_identity
    label: Process Identity
    type: string
  - name: status
    label: Status
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
save_as: data_check
```
### Dominator tree pass

- ID: `dominator_tree_pass`
- Type: `atomic`
- SQL: [`../sql/android_heap_dominator_path_extract/dominator_tree_pass.sql`](../sql/android_heap_dominator_path_extract/dominator_tree_pass.sql)

```yaml
id: dominator_tree_pass
type: atomic
optional: true
display:
  level: hidden
save_as: dominator_tree_pass
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
  - name: process_identity
    label: Process Identity
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
save_as: dominator_paths
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: data_check
  description: Heap graph sample and object availability; zero means unavailable evidence, not absence of a leak. incomplete_dump_count
    > 0 (placeholder objects or heap graph packet errors) means retained sizes are lower bounds
- name: dominator_paths
  description: Bounded per-(upid, graph_sample_ts) dominator paths with propagated root and cumulative retained size
```
