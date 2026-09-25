GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_heap_graph_leak_candidates.skill.yaml
Source SHA-256: e2af69bca6b92ed9ca91e615637c3e86b5fc9daba767af5db4f2ef7225f98f20
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# Android Heap Graph Leak Candidates

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_heap_graph_leak_candidates
version: '1.1'
type: atomic
category: memory
tier: A
```

## Metadata

```yaml
display_name: Android Heap Graph Leak Candidates
description: 基于 Java heap graph、生命周期切片和引用关系识别 Activity/Fragment 泄漏候选
icon: memory
tags:
- memory
- heap_graph
- leak
- activity
- fragment
- reference_chain
- lifecycle
```

## Triggers

```yaml
keywords:
  zh:
  - Heap Graph 泄漏
  - Java 泄漏
  - Activity 泄漏
  - Fragment 泄漏
  - 引用链
  - 生命周期泄漏
  en:
  - heap graph leak
  - java leak
  - activity leak
  - fragment leak
  - reference chain
  - lifecycle leak
patterns:
- .*(heap graph|Java heap).*(leak|泄漏|reference).*
- .*(Activity|Fragment).*(leak|泄漏).*
```

## Prerequisites

```yaml
modules:
- android.memory.heap_graph.excluded_refs
required_tables:
- heap_graph_object
- heap_graph_class
- heap_graph_reference
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（精确或 name:* 子进程）；process_name 为空时使用
- name: process_name
  type: string
  required: false
  description: 目标进程名（精确或 name:* 子进程）；为空则分析所有 heap graph 进程；无匹配时回退到没有进程名的 dump（如 .hprof）
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份；进程名不可用时（.hprof）用它限定 dump
- name: graph_sample_ts
  type: timestamp
  required: false
  description: 指定 heap graph sample 时间戳；为空分析全部 sample
- name: class_name_glob
  type: string
  required: false
  description: 额外目标 class GLOB；为空时只检查 Activity/Fragment 命名类
- name: lifecycle_slice_prefix
  type: string
  required: false
  default: SI$
  description: 生命周期切片前缀，默认匹配 SI$<class>.<method>；传空字符串可用任意前缀 FQN 匹配
- name: max_candidates
  type: integer
  required: false
  default: 50
  description: 候选 class 返回行数
- name: max_reference_edges
  type: integer
  required: false
  default: 100
  description: 引用边返回行数
```

## Ordered execution

### Heap Graph 泄漏候选

- ID: `leak_candidates`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_leak_candidates/leak_candidates.sql`](../sql/android_heap_graph_leak_candidates/leak_candidates.sql)

```yaml
id: leak_candidates
type: atomic
display:
  level: key
  layer: list
  title: Heap Graph 泄漏候选
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: graph_sample_ts
    label: Sample 时间
    type: timestamp
    unit: ns
  - name: class_name
    label: Class
    type: string
  - name: component_type
    label: 组件
    type: string
  - name: reachable_obj_count
    label: Reachable 实例
    type: number
  - name: self_size_mb
    label: Java Self(MB)
    type: number
  - name: native_size_mb
    label: Native(MB)
    type: number
  - name: lifecycle_phase_at_sample
    label: Sample 前生命周期
    type: string
  - name: process_identity
    label: 进程身份
    type: string
  - name: dump_completeness
    label: Dump 完整性
    type: string
  - name: leak_state
    label: 判定
    type: string
  - name: confidence
    label: 置信度
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
save_as: leak_candidates
```
### 候选对象保留引用来源

- ID: `reference_holders`
- Type: `atomic`
- SQL: [`../sql/android_heap_graph_leak_candidates/reference_holders.sql`](../sql/android_heap_graph_leak_candidates/reference_holders.sql)

```yaml
id: reference_holders
type: atomic
optional: true
display:
  level: detail
  layer: list
  title: 候选对象保留引用来源
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: graph_sample_ts
    label: Sample 时间
    type: timestamp
    unit: ns
  - name: candidate_class
    label: 候选 Class
    type: string
  - name: owned_object_id
    label: 对象 ID
    type: number
  - name: owner_class
    label: 保留引用来源 Class
    type: string
  - name: field_display
    label: 字段
    type: string
  - name: field_type_name
    label: 字段类型
    type: string
  - name: leak_state
    label: 候选判定
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_graph_dump_scope.sql
save_as: reference_holders
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: leak_candidates
  description: Reachable Activity/Fragment heap objects classified against sample-time lifecycle evidence; placeholder objects
    (self_size = -1) are excluded, and dump_completeness=incomplete_dump means counts and sizes are lower bounds
- name: reference_holders
  description: Small-scope incoming retaining references for suspect heap objects, excluding Perfetto _excluded_refs referent
    edges (weak/phantom/finalizer in v56; soft reference edges are not filtered by this stdlib helper)
```
