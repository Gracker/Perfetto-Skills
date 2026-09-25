GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_heap_graph_class_growth.skill.yaml
Source SHA-256: 7f3005702a7a0b160c86748bb1b535119fb9647f5d1bfa60496bf33c11551a55
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# Java Heap Class 增长对比

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_heap_graph_class_growth
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Java Heap Class 增长对比
description: 按 class 对比 Java heap dump 的实例数与 dominated 大小：同 trace 多次 dump 比首尾，前后两份 trace 经 compare_skill 对照；app class 与 libcore/数组分开排名
icon: difference
tags:
- memory
- heap_graph
- heap_dump
- leak
- class_growth
- comparison
- upstream
```

## Triggers

```yaml
keywords:
  zh:
  - heap dump 对比
  - 堆转储对比
  - Java 泄漏
  - 内存增长
  - class 增长
  - 实例增长
  - 前后对比
  en:
  - heap dump diff
  - heap dump comparison
  - class growth
  - instance growth
  - java leak
  - before after heap
patterns:
- .*(heap dump|heap graph).*(diff|compare|growth|对比|增长).*
- .*(堆转储|Java 堆).*(对比|增长|泄漏).*
```

## Prerequisites

```yaml
modules:
- android.memory.heap_graph.heap_graph_class_aggregation
- android.memory.heap_graph.heap_graph_stats
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名（精确或 name:* 子进程）；留空使用全部有 heap dump 的进程；无匹配时回退到没有进程名的 dump（如 .hprof）
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份；进程名不可用时（.hprof）用它限定 dump
- name: graph_sample_ts
  type: timestamp
  required: false
  description: 只看某一次 dump（trace 内的时间戳，compare_skill 时必须按侧分别传）；留空使用全部 dump
- name: dump_selector
  type: string
  required: false
  default: latest
  description: 排名与指定 class 行使用哪些 dump：latest（每个进程最后一次，默认）、first 或 all；compare_skill 两侧用默认值即可，无需时间戳。首尾增长总是比较全部 dump
- name: class_names
  type: string
  required: false
  description: 逗号分隔的完整 class 名；给出时为每个 dump 输出这些 class 的对齐行（不存在的 class 输出 0），用于 compare_skill 两侧对齐
- name: max_rows
  type: integer
  required: false
  default: 20
  description: 每个 dump 每个类别（app / libcore+数组）返回的 class 行数上限
```

## Ordered execution

### Heap class 聚合

- ID: `heap_class_table`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/heap_class_table.sql`](../sql/android_heap_graph_class_growth/heap_class_table.sql)

```yaml
id: heap_class_table
type: atomic
display:
  level: hidden
save_as: heap_class_table
```
### Heap dump 对比可用性

- ID: `class_growth_availability`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/class_growth_availability.sql`](../sql/android_heap_graph_class_growth/class_growth_availability.sql)

```yaml
id: class_growth_availability
type: atomic
display:
  level: key
  layer: overview
  title: Heap dump 对比可用性
  columns:
  - name: dump_count
    label: Dump 数
    type: number
  - name: process_count
    label: 进程数
    type: number
  - name: max_dumps_per_process
    label: 单进程最多 dump 数
    type: number
  - name: incomplete_dump_count
    label: 不完整 dump 数
    type: number
  - name: dump_selector
    label: 排名使用的 dump
    type: string
  - name: process_identity
    label: 进程身份
    type: string
  - name: status
    label: 状态
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
- fragments/heap_graph_selected_dumps.sql
save_as: class_growth_availability
```
### Heap dump 清单

- ID: `class_dump_inventory`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/class_dump_inventory.sql`](../sql/android_heap_graph_class_growth/class_dump_inventory.sql)

```yaml
id: class_dump_inventory
type: atomic
optional: true
display:
  level: key
  layer: list
  title: Heap dump 清单（总量平稳不代表没有泄漏）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: graph_sample_ts
    label: Dump 时间
    type: timestamp
    unit: ns
  - name: dump_index
    label: 序号
    type: number
  - name: selected_for_ranking
    label: 用于排名
    type: number
  - name: reachable_heap_bytes
    label: Reachable Heap
    type: bytes
  - name: reachable_obj_count
    label: Reachable 对象数
    type: number
  - name: dump_completeness
    label: Dump 完整性
    type: string
  - name: process_identity
    label: 进程身份
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
- fragments/heap_graph_selected_dumps.sql
save_as: class_dump_inventory
```
### Class 排名

- ID: `class_ranking`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/class_ranking.sql`](../sql/android_heap_graph_class_growth/class_ranking.sql)

```yaml
id: class_ranking
type: atomic
optional: true
display:
  level: key
  layer: list
  title: 所选 dump 的 class 按 dominated 大小排名（libcore/数组与其他 class 分开）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: graph_sample_ts
    label: Dump 时间
    type: timestamp
    unit: ns
  - name: class_category
    label: 类别
    type: string
  - name: class_name
    label: Class
    type: string
  - name: reachable_obj_count
    label: Reachable 实例数
    type: number
  - name: obj_count
    label: 实例数（含不可达）
    type: number
  - name: reachable_size_bytes
    label: Reachable 浅大小
    type: bytes
  - name: dominated_obj_count
    label: Dominated 对象数
    type: number
  - name: dominated_bytes
    label: Dominated 大小
    type: bytes
  - name: type_id_count
    label: 同名 type 数
    type: number
  - name: dump_completeness
    label: Dump 完整性
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
- fragments/heap_graph_selected_dumps.sql
save_as: class_ranking
```
### 指定 class 对齐行

- ID: `requested_classes`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/requested_classes.sql`](../sql/android_heap_graph_class_growth/requested_classes.sql)

```yaml
id: requested_classes
type: atomic
optional: true
display:
  level: key
  layer: list
  title: 指定 class 在所选 dump 中的对齐行
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: graph_sample_ts
    label: Dump 时间
    type: timestamp
    unit: ns
  - name: class_name
    label: Class
    type: string
  - name: present_in_dump
    label: 存在
    type: number
  - name: reachable_obj_count
    label: Reachable 实例数
    type: number
  - name: obj_count
    label: 实例数（含不可达）
    type: number
  - name: dominated_bytes
    label: Dominated 大小
    type: bytes
  - name: dump_completeness
    label: Dump 完整性
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
- fragments/heap_graph_selected_dumps.sql
save_as: requested_classes
```
### 同 trace 首尾 dump class 增长

- ID: `class_growth_within_trace`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_class_growth/class_growth_within_trace.sql`](../sql/android_heap_graph_class_growth/class_growth_within_trace.sql)

```yaml
id: class_growth_within_trace
type: atomic
optional: true
condition: class_growth_availability.data[0]?.status === 'multiple_dumps'
display:
  level: key
  layer: list
  title: 首次 → 末次 heap dump 的 class 增长（libcore/数组与其他 class 分开排名）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: class_category
    label: 类别
    type: string
  - name: class_name
    label: Class
    type: string
  - name: baseline_reachable_count
    label: 首次 Reachable 实例
    type: number
  - name: target_reachable_count
    label: 末次 Reachable 实例
    type: number
  - name: reachable_count_delta
    label: Reachable 实例增量
    type: number
  - name: baseline_dominated_bytes
    label: 首次 Dominated
    type: bytes
  - name: target_dominated_bytes
    label: 末次 Dominated
    type: bytes
  - name: dominated_delta_bytes
    label: Dominated 增量
    type: bytes
  - name: growth_signal
    label: 增长信号
    type: string
  - name: monotonic_growth
    label: 逐次不减
    type: number
  - name: dump_count
    label: Dump 数
    type: number
  - name: comparability
    label: 可比性
    type: string
  - name: baseline_ts
    label: 首次 Dump
    type: timestamp
    unit: ns
  - name: target_ts
    label: 末次 Dump
    type: timestamp
    unit: ns
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
save_as: class_growth_within_trace
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: class_growth_availability
  description: 'Dump count and status: multiple_dumps enables first-vs-last growth; single_dump means compare against a reference
    trace with compare_skill'
- name: class_dump_inventory
  description: Every dump with its reachable heap size, completeness and whether dump_selector used it for ranking; a flat
    heap total does not rule out a class-level leak
- name: class_ranking
  description: 'Selected dumps: classes ranked by dominated bytes from android_heap_graph_class_aggregation, libcore/array
    classes (usually retained payload) apart from application and framework classes; counts exclude placeholder objects'
- name: requested_classes
  description: Aligned rows for the requested class_names in each selected dump, with explicit zero rows, for cross-trace
    comparison or a per-dump series
- name: class_growth_within_trace
  description: First-vs-last dump class growth per process on reachable instance counts and dominated bytes; instance_growth
    marks classes whose count grew, retained_growth_only marks holders whose dominated set grew with a flat count, retained_growth_fewer_instances
    marks fewer instances retaining more; monotonic_growth is 0 when any dump in between dropped
```
