GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/global_trace_sanity_check.skill.yaml
Source SHA-256: 3c4b708b7b84c9206463877bf914275bb2d48df15eef7c821ebe6eeaf4a8e263
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# 全局 Trace Sanity 检查

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: global_trace_sanity_check
version: '1.0'
type: composite
category: system
tier: S
```

## Metadata

```yaml
display_name: 全局 Trace Sanity 检查
description: 在目标时间窗内快速枚举最长 slice、D 状态、Runnable 等待、Runqueue 压力和 CPU 热点进程
icon: fact_check
tags:
- system
- sanity
- trace
- scheduler
- cpu
- global
```

## Triggers

```yaml
keywords:
  zh:
  - 全局检查
  - trace sanity
  - 系统级瓶颈
  - 全局瓶颈
  - 最长slice
  - D状态
  - runnable等待
  en:
  - global sanity
  - trace sanity
  - system stall
  - longest slices
  - d-state
  - runnable wait
patterns:
- .*(global|trace).*sanity.*
- .*(全局|系统).*瓶颈.*
- .*最长.*slice.*
- .*D.*状态.*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_state
- sched_slice
modules:
- sched.thread_level_parallelism
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)，默认 trace_start()
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)，默认 trace_end()
- name: max_rows
  type: integer
  required: false
  default: 20
  description: 每个明细表最大返回行数
```

## Ordered execution

### Trace 时间窗

- ID: `trace_window`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/trace_window.sql`](../sql/global_trace_sanity_check/trace_window.sql)

```yaml
id: trace_window
type: atomic
synthesize:
  role: overview
  fields:
  - key: start_ts
    label: 起点
  - key: end_ts
    label: 终点
  - key: duration_ms
    label: 时长
    format: duration_ms
display:
  level: summary
  layer: overview
  title: 全局检查时间窗
  columns:
  - name: start_ts
    label: 起点
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: end_ts
    label: 终点
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: duration_ms
    label: 时长
    type: duration
    unit: ms
    format: duration_ms
  - name: max_rows
    label: 明细上限
    type: number
save_as: trace_window
```
### 最长 Slice

- ID: `top_long_slices`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/top_long_slices.sql`](../sql/global_trace_sanity_check/top_long_slices.sql)

```yaml
id: top_long_slices
type: atomic
synthesize:
  role: list
  fields:
  - key: slice_name
    label: Slice
  - key: duration_ms
    label: 时长
    format: duration_ms
  - key: process_name
    label: 进程
  - key: thread_name
    label: 线程
display:
  level: detail
  layer: list
  title: 时间窗内最长 Slice
  columns:
  - name: ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: duration_ms
    label: 时长
    type: duration
    unit: ms
    format: duration_ms
  - name: slice_name
    label: Slice
    type: string
    format: truncate
  - name: process_name
    label: 进程
    type: string
    format: truncate
  - name: thread_name
    label: 线程
    type: string
    format: truncate
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: slice_start_ts
    label: 原始Slice开始
    type: timestamp
    unit: ns
    hidden: true
  - name: slice_dur_ns
    label: 原始Slice时长
    type: duration
    unit: ns
    hidden: true
save_as: top_long_slices
```
### D 状态线程

- ID: `top_d_state_threads`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/top_d_state_threads.sql`](../sql/global_trace_sanity_check/top_d_state_threads.sql)

```yaml
id: top_d_state_threads
type: atomic
synthesize:
  role: list
  fields:
  - key: process_name
    label: 进程
  - key: thread_name
    label: 线程
  - key: total_blocked_ms
    label: D状态总时长
    format: duration_ms
  - key: blocked_function
    label: 阻塞函数
display:
  level: detail
  layer: list
  title: D 状态线程 Top
  columns:
  - name: total_blocked_ms
    label: 总阻塞
    type: duration
    unit: ms
    format: duration_ms
  - name: max_blocked_ms
    label: 最长单次
    type: duration
    unit: ms
    format: duration_ms
  - name: events
    label: 次数
    type: number
  - name: process_name
    label: 进程
    type: string
    format: truncate
  - name: thread_name
    label: 线程
    type: string
    format: truncate
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: pid
    label: pid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: tid
    label: tid
    type: number
    hidden: true
  - name: blocked_function
    label: 阻塞函数
    type: string
    format: truncate
  - name: first_ts
    label: 首次
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
save_as: top_d_state_threads
```
### Runnable 等待线程

- ID: `top_runnable_waits`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/top_runnable_waits.sql`](../sql/global_trace_sanity_check/top_runnable_waits.sql)

```yaml
id: top_runnable_waits
type: atomic
synthesize:
  role: list
  fields:
  - key: process_name
    label: 进程
  - key: thread_name
    label: 线程
  - key: total_runnable_wait_ms
    label: Runnable总等待
    format: duration_ms
  - key: max_runnable_wait_ms
    label: 最长单次等待
    format: duration_ms
display:
  level: detail
  layer: list
  title: Runnable 等待 Top
  columns:
  - name: total_runnable_wait_ms
    label: 总等待
    type: duration
    unit: ms
    format: duration_ms
  - name: max_runnable_wait_ms
    label: 最长单次
    type: duration
    unit: ms
    format: duration_ms
  - name: events
    label: 次数
    type: number
  - name: process_name
    label: 进程
    type: string
    format: truncate
  - name: thread_name
    label: 线程
    type: string
    format: truncate
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: pid
    label: pid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: tid
    label: tid
    type: number
    hidden: true
  - name: first_ts
    label: 首次
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
save_as: top_runnable_waits
```
### Runqueue 压力

- ID: `runqueue_pressure`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/runqueue_pressure.sql`](../sql/global_trace_sanity_check/runqueue_pressure.sql)

```yaml
id: runqueue_pressure
type: atomic
synthesize:
  role: overview
  fields:
  - key: max_runnable_threads
    label: 最大Runnable线程数
  - key: avg_runnable_threads
    label: 平均Runnable线程数
  - key: p95_runnable_threads
    label: P95Runnable线程数
display:
  level: summary
  layer: overview
  title: Runqueue 压力
  columns:
  - name: samples
    label: 样本数
    type: number
  - name: avg_runnable_threads
    label: 平均Runnable
    type: number
  - name: p95_runnable_threads
    label: P95Runnable
    type: number
  - name: max_runnable_threads
    label: 最大Runnable
    type: number
  - name: cpu_count
    label: CPU数
    type: number
  - name: runnable_wait_ge4_ms
    label: Runnable>=4时长
    type: duration
    unit: ms
    format: duration_ms
  - name: over_cpu_capacity_ms
    label: 超过CPU容量时长
    type: duration
    unit: ms
    format: duration_ms
  - name: pressure_weighted_ms
    label: 超过CPU容量时长
    type: duration
    unit: ms
    format: duration_ms
    hidden: true
save_as: runqueue_pressure
```
### CPU 热点进程

- ID: `top_cpu_processes`
- Type: `atomic`
- SQL: [`../sql/global_trace_sanity_check/top_cpu_processes.sql`](../sql/global_trace_sanity_check/top_cpu_processes.sql)

```yaml
id: top_cpu_processes
type: atomic
synthesize:
  role: list
  fields:
  - key: process_name
    label: 进程
  - key: cpu_time_ms
    label: CPU时间
    format: duration_ms
  - key: sched_slices
    label: 调度片数
display:
  level: detail
  layer: list
  title: 时间窗内 CPU 热点进程
  columns:
  - name: cpu_time_ms
    label: CPU时间
    type: duration
    unit: ms
    format: duration_ms
  - name: sched_slices
    label: 调度片数
    type: number
  - name: process_name
    label: 进程
    type: string
    format: truncate
  - name: process_key
    label: process_key
    type: number
    hidden: true
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: pid
    label: pid
    type: number
    hidden: true
  - name: thread_count
    label: 线程数
    type: number
  - name: first_ts
    label: 首次
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
save_as: top_cpu_processes
```
## Output and evidence contract

```yaml
format: structured
```
