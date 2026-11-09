GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/runnable_cpu_occupancy_in_range.skill.yaml
Source SHA-256: a49f4b9043c7f6d13ecf147f6202d2d1ffa887e62e7a71c78d89663a5717587f
# Runnable 等待期间目标 CPU 的占用者

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: runnable_cpu_occupancy_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Runnable 等待期间目标 CPU 的占用者
display_name_i18n:
  en: Occupants of the waited-for CPU during Runnable waits
description: 目标线程 R/R+ 等待期间，其随后运行的 CPU 上实际运行的任务、idle 与未覆盖时间；观测不等于抢占原因
description_i18n:
  en: Tasks, idle and uncovered time on the CPU each target thread later ran on, during its R/R+ waits; an observation, not
    a preemption cause
icon: analytics
tags:
- system
- scheduling
- evidence
- range
```

## Prerequisites

```yaml
modules:
- linux.threads
- intervals.intersect
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 窗口起点(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 窗口终点(ns)
- name: package
  type: string
  required: false
  description: 目标进程名（精确匹配，含 name:* 子进程）
- name: utid
  type: number
  required: false
  description: 只看这一个目标线程（可选）
- name: max_targets
  type: integer
  required: false
  default: 4
  description: 按窗口内 Runnable 时长保留的非主线程目标数；主线程另计，同样按此上限（至少 1 个）保留
- name: max_occupants
  type: integer
  required: false
  default: 5
  description: 每个目标线程 × CPU 单独列出的占用任务数，其余合并为 other_tasks 行
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/runnable_cpu_occupancy_in_range/query.sql`](../sql/runnable_cpu_occupancy_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: Runnable 等待期间目标 CPU 的占用者
row_semantics: per_entity
columns:
- name: window_id
  label: window_id
  type: number
  hidden: true
- name: window_start_ts
  label: window_start_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_end_ts
  label: window_end_ts
  type: timestamp
  unit: ns
  hidden: true
- name: window_dur_ns
  label: window_dur_ns
  type: duration
  unit: ns
  hidden: true
- name: upid
  label: upid
  type: number
- name: pid
  label: pid
  type: number
- name: process_name
  label: process_name
  type: string
- name: utid
  label: utid
  type: number
- name: tid
  label: tid
  type: number
- name: thread_name
  label: thread_name
  type: string
- name: role
  label: role
  type: string
- name: runnable_ns
  label: runnable_ns
  type: duration
  unit: ns
- name: targets_with_runnable
  label: targets_with_runnable
  type: number
  unit: count
- name: targets_omitted
  label: targets_omitted
  type: number
  unit: count
- name: ucpu
  label: ucpu
  type: number
- name: cpu
  label: cpu
  type: number
- name: cpu_basis
  label: cpu_basis
  type: string
- name: cpu_runnable_ns
  label: cpu_runnable_ns
  type: duration
  unit: ns
- name: cpu_segment_count
  label: cpu_segment_count
  type: number
  unit: count
- name: idle_ns
  label: idle_ns
  type: duration
  unit: ns
- name: unattributed_ns
  label: unattributed_ns
  type: duration
  unit: ns
- name: occupant_kind
  label: occupant_kind
  type: string
- name: occupant_rank
  label: occupant_rank
  type: number
- name: occupant_utid
  label: occupant_utid
  type: number
- name: occupant_tid
  label: occupant_tid
  type: number
- name: occupant_thread_name
  label: occupant_thread_name
  type: string
- name: occupant_upid
  label: occupant_upid
  type: number
- name: occupant_pid
  label: occupant_pid
  type: number
- name: occupant_process_name
  label: occupant_process_name
  type: string
- name: occupant_is_kernel
  label: occupant_is_kernel
  type: number
- name: occupant_count
  label: occupant_count
  type: number
  unit: count
- name: occupied_ns
  label: occupied_ns
  type: duration
  unit: ns
  semantics: Time this occupant ran on the CPU while the target thread waited Runnable for it (eventual_run_cpu), clipped
    to those waits. An observation of who ran there, not a preemption cause.
- name: segment_count
  label: segment_count
  type: number
  unit: count
- name: share_of_runnable
  label: share_of_runnable
  type: number
  semantics: 'occupied_ns / cpu_runnable_ns as a 0-1 fraction: the share of this target thread''s Runnable wait on this CPU
    that the occupant covered.'
- name: occupancy_evidence
  label: occupancy_evidence
  type: string
- name: kernel_thread_source
  label: kernel_thread_source
  type: string
- name: evidence_scope
  label: evidence_scope
  type: string
```
