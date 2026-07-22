GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/android_memory_v57_ai_diagnostics.skill.yaml
Source SHA-256: 7dc0d526cc82e5a6cdcf44d923ed6b520120af61b4527abee948ab91566875da
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# Android Memory v57 AI Diagnostics

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_memory_v57_ai_diagnostics
version: '1.0'
type: composite
category: memory
tier: B
```

## Metadata

```yaml
display_name: Android Memory v57 AI Diagnostics
description: Translate Perfetto v57 Android memory Agent Skill SQL into deterministic heap graph and heap profile evidence
icon: memory
tags:
- memory
- heap_graph
- heap_profile
- heapprofd
- upstream_v57
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - v57 内存
  - Perfetto AI 内存
  - heap graph
  - Java allocation
  - native heap
  - 对象频率
  en:
  - v57 memory
  - perfetto ai memory
  - heap graph
  - java allocation
  - native heap
  - object frequency
patterns:
- .*(v57|Perfetto AI).*(memory|heap).*
- .*(heap graph|java allocation|native heap).*
```

## Prerequisites

```yaml
modules:
- prelude.after_eof.memory
- prelude.after_eof.views
- android.memory.heap_graph.heap_graph_stats
- android.memory.heap_graph.class_summary_tree
- android.memory.heap_profile.summary_tree
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: Optional process name substring for heap graph rows
- name: graph_sample_ts
  type: timestamp
  required: false
  description: Optional heap graph sample timestamp
- name: min_size_mb
  type: number
  required: false
  default: 1
  description: Minimum heap profile size in MB
- name: max_rows
  type: integer
  required: false
  default: 40
  description: Maximum rows per diagnostic table
```

## Ordered execution

### Memory v57 data availability

- ID: `data_check`
- Type: `atomic`
- SQL: [`../sql/android_memory_v57_ai_diagnostics/data_check.sql`](../sql/android_memory_v57_ai_diagnostics/data_check.sql)

```yaml
id: data_check
type: atomic
display:
  level: hidden
save_as: data_check
```
### Repeated heap graph object classes

- ID: `heap_graph_repeated_objects`
- Type: `atomic`
- SQL: [`../sql/android_memory_v57_ai_diagnostics/heap_graph_repeated_objects.sql`](../sql/android_memory_v57_ai_diagnostics/heap_graph_repeated_objects.sql)

```yaml
id: heap_graph_repeated_objects
type: atomic
optional: true
condition: data_check.data[0]?.heap_graph_class_rows > 0
display:
  level: detail
  layer: list
  title: Repeated Heap Graph Classes
  columns:
  - name: process_name
    label: Process
    type: string
  - name: graph_sample_ts
    label: Sample
    type: timestamp
    unit: ns
  - name: class_name
    label: Class
    type: string
  - name: root_type
    label: Root
    type: string
  - name: path_count
    label: Paths
    type: number
  - name: total_objects
    label: Objects
    type: number
  - name: total_retained_mb
    label: Retained(MB)
    type: number
  - name: single_object_self_size
    label: Self Size
    type: number
  - name: single_object_cumulative_size
    label: Retained Size
    type: number
save_as: heap_graph_repeated_objects
```
### Heap graph object size frequencies

- ID: `heap_graph_size_frequencies`
- Type: `atomic`
- SQL: [`../sql/android_memory_v57_ai_diagnostics/heap_graph_size_frequencies.sql`](../sql/android_memory_v57_ai_diagnostics/heap_graph_size_frequencies.sql)

```yaml
id: heap_graph_size_frequencies
type: atomic
optional: true
condition: data_check.data[0]?.heap_graph_objects > 0
display:
  level: detail
  layer: list
  title: Heap Graph Size Frequencies
  columns:
  - name: process_name
    label: Process
    type: string
  - name: graph_sample_ts
    label: Sample
    type: timestamp
    unit: ns
  - name: class_name
    label: Class
    type: string
  - name: single_object_self_size
    label: Self Size
    type: number
  - name: occurrence_count
    label: Count
    type: number
  - name: total_self_mb
    label: Self Total(MB)
    type: number
  - name: reachable_count
    label: Reachable
    type: number
save_as: heap_graph_size_frequencies
```
### Heap profile allocation hotspots

- ID: `heap_profile_hotspots`
- Type: `atomic`
- SQL: [`../sql/android_memory_v57_ai_diagnostics/heap_profile_hotspots.sql`](../sql/android_memory_v57_ai_diagnostics/heap_profile_hotspots.sql)

```yaml
id: heap_profile_hotspots
type: atomic
optional: true
condition: data_check.data[0]?.heap_profile_summary_rows > 0
display:
  level: detail
  layer: list
  title: Heap Profile Allocation Hotspots
  columns:
  - name: scope
    label: Scope
    type: string
  - name: name
    label: Frame
    type: string
  - name: mapping_name
    label: Mapping
    type: string
  - name: self_size_mb
    label: Self Retained(MB)
    type: number
  - name: cumulative_size_mb
    label: Cumulative Retained(MB)
    type: number
  - name: self_alloc_mb
    label: Self Alloc(MB)
    type: number
  - name: cumulative_alloc_mb
    label: Cumulative Alloc(MB)
    type: number
  - name: allocation_signal
    label: Signal
    type: string
  - name: source_file
    label: Source
    type: string
save_as: heap_profile_hotspots
```
### Memory v57 no-data contract

- ID: `no_data_contract`
- Type: `atomic`
- SQL: [`../sql/android_memory_v57_ai_diagnostics/no_data_contract.sql`](../sql/android_memory_v57_ai_diagnostics/no_data_contract.sql)

```yaml
id: no_data_contract
type: atomic
optional: true
condition: data_check.data[0]?.heap_graph_class_rows === 0 && data_check.data[0]?.heap_graph_objects === 0 && data_check.data[0]?.heap_profile_summary_rows
  === 0
display:
  level: summary
  layer: overview
  title: Memory v57 Data Availability
  columns:
  - name: status
    label: Status
    type: string
  - name: heap_graph_samples
    label: Heap Graph Samples
    type: number
  - name: heap_profile_allocations
    label: Heap Profile Allocations
    type: number
save_as: no_data_contract
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: heap_graph_repeated_objects
  description: Repeated class/root paths translated from upstream query_most_repeated_objects.sql
- name: heap_graph_size_frequencies
  description: Object size frequency rows translated from upstream query_size_frequencies.sql
- name: heap_profile_hotspots
  description: Heap profile summary-tree allocation hotspots for Java/native allocation profile workflows
```
