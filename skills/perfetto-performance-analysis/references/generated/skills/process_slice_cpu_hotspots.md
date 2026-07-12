GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/process_slice_cpu_hotspots.skill.yaml
Source SHA-256: fd6bc72d2cee67b783f9795e253586db60f2b7a3c3e786495b6d998e69403a8a
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# 进程 Slice CPU 热点

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: process_slice_cpu_hotspots
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 进程 Slice CPU 热点
description: 按进程聚合 named slice 的实际 Running CPU 时间
icon: query_stats
tags:
- cpu
- slice
- thread_state
- running
- hotspot
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - slice CPU
  - 函数 CPU
  - 热点 slice
  - CPU 热点
  - Running 时间
  - named slice
  en:
  - slice cpu
  - function cpu
  - hot slices
  - cpu hotspots
  - running time
  - named slice
patterns:
- .*(slice|函数|方法).*(CPU|cpu|消耗|热点).*
- .*(CPU|cpu).*(slice|function|method|named).*
```

## Prerequisites

```yaml
modules: null
required_tables:
- slice
- thread_track
- thread
- process
- thread_state
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标应用包名或进程名前缀
- name: process_name
  type: string
  required: false
  description: 目标进程名；当 package 为空时使用
- name: upid
  type: integer
  required: false
  description: 可选 trace 内进程 ID；优先级高于 package/process_name
- name: slice_name
  type: string
  required: false
  description: 可选 slice 名称过滤；默认字面包含匹配，包含 % 时按 SQL LIKE 模式匹配
- name: thread_scope
  type: string
  required: false
  default: all
  description: 线程范围：all/main/render/main_render
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)，默认 trace_start()
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)，默认 trace_end()
- name: min_cpu_ns
  type: integer
  required: false
  default: 0
  description: 聚合后最小 CPU 时间阈值(ns)
- name: top_k
  type: integer
  required: false
  default: 10
  description: 返回 TopK 条目
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
- process_name
rewriteTo: recommended_process_name_param
```

## Query

Run [`../sql/process_slice_cpu_hotspots/query.sql`](../sql/process_slice_cpu_hotspots/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 进程 Slice CPU 热点
columns:
- name: process_name
  label: 进程
  type: string
  format: truncate
- name: slice_name
  label: Slice
  type: string
  format: truncate
- name: count
  label: 次数
  type: number
  format: compact
- name: thread_count
  label: 线程数
  type: number
  format: compact
- name: sample_threads
  label: 样例线程
  type: string
  format: truncate
- name: total_cpu_ms
  label: CPU时间
  type: duration
  format: duration_ms
  unit: ms
- name: total_wall_ms
  label: Wall时间
  type: duration
  format: duration_ms
  unit: ms
- name: avg_cpu_ms
  label: 平均CPU
  type: duration
  format: duration_ms
  unit: ms
- name: max_cpu_ms
  label: 最大CPU
  type: duration
  format: duration_ms
  unit: ms
- name: cpu_efficiency_pct
  label: CPU/Wall
  type: percentage
  format: percentage
- name: selected_cpu_share_pct
  label: 所选CPU占比
  type: percentage
  format: percentage
- name: first_ts
  label: 首次出现
  type: timestamp
- name: last_ts
  label: 最后出现
  type: timestamp
```
