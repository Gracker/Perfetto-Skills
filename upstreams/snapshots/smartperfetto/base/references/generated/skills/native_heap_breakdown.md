GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/native_heap_breakdown.skill.yaml
Source SHA-256: 9de17b88dbea86451c2107ac4494967a6a6bb290b473eefe52f7650cc9e00550
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# Native Heap 分解

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: native_heap_breakdown
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Native Heap 分解
description: 基于 heapprofd summary tree 输出 native heap 未释放和累计分配热点
icon: account_tree
tags:
- memory
- native_heap
- heapprofd
- allocation
- leak
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
  en:
  - native heap
  - heapprofd
  - native memory
  - malloc leak
  - allocation
patterns:
- .*(native heap|heapprofd|malloc).*(泄漏|增长|热点).*
- .*(native heap|heapprofd|malloc).*(leak|growth|hotspot).*
```

## Prerequisites

```yaml
modules:
- android.memory.heap_profile.summary_tree
```

## Inputs

```yaml
- name: min_size_mb
  type: number
  required: false
  description: 最小累计未释放大小(MB)，默认 1
- name: min_alloc_mb
  type: number
  required: false
  description: 最小累计分配大小(MB)，默认 0；用于捕获已释放但分配量很高的 churn 热点
- name: max_rows
  type: number
  required: false
  description: 返回行数上限，默认 100
```

## Ordered execution

### Native Heap 热点

- ID: `native_heap_hotspots`
- Type: `atomic`
- SQL: [`../sql/native_heap_breakdown/native_heap_hotspots.sql`](../sql/native_heap_breakdown/native_heap_hotspots.sql)

```yaml
id: native_heap_hotspots
type: atomic
display:
  level: detail
  layer: list
  title: Native Heap Allocation Hotspots
  columns:
  - name: name
    label: 函数/符号
    type: string
  - name: mapping_name
    label: Mapping
    type: string
  - name: cumulative_size_mb
    label: 累计未释放(MB)
    type: number
  - name: self_size_mb
    label: 自身未释放(MB)
    type: number
  - name: cumulative_alloc_mb
    label: 累计分配(MB)
    type: number
  - name: unreleased_to_alloc_pct
    label: 未释放/累计分配(%)
    type: percentage
  - name: churn_ratio
    label: Churn 倍数
    type: number
  - name: native_signal
    label: Native 信号
    type: string
  - name: source_file
    label: 源码
    type: string
save_as: native_heap_hotspots
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: cumulative_size_mb
  description: heapprofd summary tree 中当前仍未释放的累计 native allocation；只能覆盖 profiler 启动后的 native malloc/free 族分配。
- name: cumulative_alloc_mb
  description: heapprofd 观测窗口内累计分配量；高累计分配但低未释放通常代表 allocation churn，而不是已证明泄漏。
- name: native_signal
  description: 按未释放保留与累计分配 churn 粗分的诊断信号，需结合 RSS/Swap、heap graph 和采集窗口解释。
```
