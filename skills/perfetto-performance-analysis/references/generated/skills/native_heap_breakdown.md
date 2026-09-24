GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/native_heap_breakdown.skill.yaml
Source SHA-256: c60782edef05f79ebd9a79e7f0f8f3f2dfec35cd35c839c661f0f34a68681fff
Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df
# Heap Profile 分解（Native / Java 分配）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: native_heap_breakdown
version: '2.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Heap Profile 分解（Native / Java 分配）
description: 按进程 × heap 拆分 heapprofd 分配：native 区分未释放保留与分配 churn，Java(com.android.art) 只报分配 churn；热点归因到分配器之上的第一个应用/库帧
icon: account_tree
tags:
- memory
- native_heap
- heapprofd
- allocation
- leak
- java_allocation
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - native heap
  - heapprofd
  - native 内存
  - C++ 内存
  - malloc 泄漏
  - Java 分配
  - 分配抖动
  en:
  - native heap
  - heapprofd
  - native memory
  - malloc leak
  - allocation
  - java allocation
  - allocation churn
patterns:
- .*(native heap|heapprofd|malloc).*(泄漏|增长|热点).*
- .*(native heap|heapprofd|malloc).*(leak|growth|hotspot).*
```

## Prerequisites

```yaml
modules:
- callstacks.stack_profile
```

## Inputs

```yaml
- name: min_size_mb
  type: number
  required: false
  description: 热点门槛(MB)：native 按归因未释放大小，Java 按归因分配大小，默认 1
- name: min_alloc_mb
  type: number
  required: false
  description: 最小分配量(MB)，默认 0；用于捕获已释放但分配量很高的 churn 热点
- name: max_rows
  type: number
  required: false
  description: 返回行数上限，默认 100
- name: process_name
  type: string
  required: false
  description: 目标进程名（精确或 name:* 子进程，见 fragments/heap_target_process.sql）；留空分析全部 heapprofd 进程
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份
```

## Ordered execution

### Heap Profile 清单

- ID: `heap_profile_inventory`
- Type: `atomic`
- SQL: [`../sql/native_heap_breakdown/heap_profile_inventory.sql`](../sql/native_heap_breakdown/heap_profile_inventory.sql)

```yaml
id: heap_profile_inventory
type: atomic
display:
  level: key
  layer: overview
  title: heapprofd Profiles (per process × heap)
  columns:
  - name: upid
    label: UPID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: heap_name
    label: Heap
    type: string
  - name: heap_semantics
    label: Heap 语义
    type: string
  - name: alloc_mb
    label: 累计分配(MB)
    type: number
  - name: unreleased_mb
    label: 未释放(MB)
    type: number
  - name: alloc_count
    label: 分配次数(采样)
    type: number
  - name: unreleased_count
    label: 未释放次数(采样)
    type: number
  - name: retention_claim
    label: 能否判断保留
    type: string
  - name: heapprofd_issues
    label: heapprofd 截断/错误
    type: string
  - name: process_identity
    label: 进程身份
    type: string
  - name: status
    label: 状态
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_profile_scope.sql
save_as: heap_profile_inventory
```
### Heap Profile 热点

- ID: `native_heap_hotspots`
- Type: `atomic`
- SQL: [`../sql/native_heap_breakdown/native_heap_hotspots.sql`](../sql/native_heap_breakdown/native_heap_hotspots.sql)

```yaml
id: native_heap_hotspots
type: atomic
display:
  level: detail
  layer: list
  title: Heap Profile Allocation Hotspots (per process × heap)
  columns:
  - name: upid
    label: UPID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: heap_name
    label: Heap
    type: string
  - name: name
    label: 归因帧(分配器之上首个应用/库帧)
    type: string
  - name: mapping_name
    label: Mapping
    type: string
  - name: cumulative_size_mb
    label: 累计未释放(MB)
    type: number
  - name: self_size_mb
    label: 归因未释放(MB)
    type: number
  - name: cumulative_alloc_mb
    label: 累计分配(MB)
    type: number
  - name: self_alloc_mb
    label: 归因分配(MB)
    type: number
  - name: self_alloc_count
    label: 归因分配次数(采样)
    type: number
  - name: unreleased_to_alloc_pct
    label: 未释放/累计分配(%)
    type: percentage
  - name: churn_ratio
    label: Churn 倍数
    type: number
  - name: native_signal
    label: 信号
    type: string
  - name: source_file
    label: 源码
    type: string
sql_fragments:
- fragments/heap_target_process.sql
- fragments/heap_profile_scope.sql
save_as: native_heap_hotspots
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: heap_profile_inventory
  description: 每个 (进程, heap) profile 的累计分配/未释放总量与 heap 语义；com.android.art 只记录分配、不记录 GC 释放，未释放恒等于分配，只能说明分配 churn；heapprofd_issues
    非 none 时 profile 可能被截断或丢样本。
- name: cumulative_size_mb
  description: 该帧所在调用栈在本 (进程, heap) 内当前仍未释放的累计分配；只覆盖 profiler 启动后的分配。不记录释放的 heap（com.android.art 等）为 NULL：未释放不可测量，不能当作保留。
- name: self_size_mb
  description: 以该帧为分配器之上首个应用/库帧归因的未释放量；native 保留候选按此列判断。
- name: cumulative_alloc_mb
  description: heapprofd 观测窗口内累计分配量；高累计分配但低未释放通常代表 allocation churn，而不是已证明泄漏。
- name: native_signal
  description: 按 heap 语义分类：com.android.art 或无释放记录的 heap 只会是 allocation_churn / inspect_if_relevant；可测量释放的 native heap 才可能是
    unreleased_native_retention / retention_with_churn；call_path_ancestor 为无直接归因的调用路径上层帧。需结合 RSS/Swap、heap graph 和采集窗口解释。
```
