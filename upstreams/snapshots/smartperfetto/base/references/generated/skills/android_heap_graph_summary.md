GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_heap_graph_summary.skill.yaml
Source SHA-256: e4b8220ce04f7c700df3feb487e732421353aeda901ecc144e00008b8cc3b2d6
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# Android Heap Graph Summary

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_heap_graph_summary
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Android Heap Graph Summary
description: 检查 Android Java heap graph 数据，并按 retained/cumulative size 找出主要 class retainer
icon: memory
tags:
- memory
- heap_graph
- leak
- retained_size
- upstream
```

## Triggers

```yaml
keywords:
  zh:
  - Java heap dump
  - heap graph
  - 堆转储
  - Java 泄漏
  - retained size
  - dominator
  en:
  - java heap dump
  - heap graph
  - retained size
  - dominator
  - leak
patterns:
- .*(heap dump|heap graph|retained size|dominator).*
- .*(堆转储|Java.*泄漏|保留大小).*
```

## Prerequisites

```yaml
modules:
- android.memory.heap_graph.heap_graph_stats
- android.memory.heap_graph.class_summary_tree
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名；留空分析全部 heap graph sample
- name: graph_sample_ts
  type: timestamp
  required: false
  description: 指定 heap graph sample 时间戳；留空使用全部 sample
- name: max_rows
  type: integer
  required: false
  default: 30
  description: top class retainer 返回行数
```

## Ordered execution

### Heap Graph 数据可用性

- ID: `heap_graph_availability`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_summary/heap_graph_availability.sql`](../sql/android_heap_graph_summary/heap_graph_availability.sql)

```yaml
id: heap_graph_availability
type: atomic
display:
  level: key
  layer: overview
  title: Heap Graph 数据可用性
  columns:
  - name: sample_count
    label: Sample 数
    type: number
  - name: process_count
    label: 进程数
    type: number
  - name: reachable_heap_mb
    label: Reachable Heap(MB)
    type: number
  - name: total_heap_mb
    label: Total Heap(MB)
    type: number
  - name: status
    label: 状态
    type: string
save_as: heap_graph_availability
```
### Heap Graph Samples

- ID: `heap_graph_samples`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_summary/heap_graph_samples.sql`](../sql/android_heap_graph_summary/heap_graph_samples.sql)

```yaml
id: heap_graph_samples
type: atomic
optional: true
display:
  level: key
  layer: list
  title: Heap Graph Samples
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: graph_sample_ts
    label: Sample 时间
    type: timestamp
    unit: ns
  - name: reachable_heap_mb
    label: Reachable Heap(MB)
    type: number
  - name: total_heap_mb
    label: Total Heap(MB)
    type: number
  - name: reachable_obj_count
    label: Reachable 对象数
    type: number
  - name: total_obj_count
    label: 对象总数
    type: number
  - name: anon_rss_and_swap_mb
    label: Anon RSS+Swap(MB)
    type: number
  - name: oom_score_adj
    label: OOM adj
    type: number
  - name: unreachable_heap_mb
    label: Unreachable Heap(MB)
    type: number
save_as: heap_graph_samples
```
### Top Retained Classes

- ID: `top_retained_classes`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_summary/top_retained_classes.sql`](../sql/android_heap_graph_summary/top_retained_classes.sql)

```yaml
id: top_retained_classes
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: Top Retained Classes
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: graph_sample_ts
    label: Sample 时间
    type: timestamp
    unit: ns
  - name: class_name
    label: Class
    type: string
  - name: root_type
    label: Root Type
    type: string
  - name: self_count
    label: Self Count
    type: number
  - name: self_size_mb
    label: Self Size(MB)
    type: number
  - name: cumulative_count
    label: Retained Count
    type: number
  - name: cumulative_size_mb
    label: Retained Size(MB)
    type: number
  - name: retained_pct_of_sample
    label: Sample 占比
    type: percentage
    format: percentage
  - name: leak_hint
    label: 风险提示
    type: string
save_as: top_retained_classes
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: heap_graph_availability
  description: Heap graph sample/data availability
- name: heap_graph_samples
  description: Heap graph sample-level heap/RSS/OOM orientation
- name: top_retained_classes
  description: Class retained-size ranking from android_heap_graph_class_summary_tree
```
