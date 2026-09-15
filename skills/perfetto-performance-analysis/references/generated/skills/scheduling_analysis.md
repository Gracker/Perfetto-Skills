GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/scheduling_analysis.skill.yaml
Source SHA-256: b31cc396cd518f4b46e71db1d3f0fde3f4eec0116380fc97e47ca43bf7c5bc93
Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5
# 调度延迟分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scheduling_analysis
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 调度延迟分析
description: 分析线程调度延迟 (Runnability)
icon: schedule
tags:
- scheduling
- kernel
- latency
- atomic
```

## Prerequisites

```yaml
required_tables:
- sched_slice
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: package
  type: string
  required: false
```

## Query

Run [`../sql/scheduling_analysis/query.sql`](../sql/scheduling_analysis/query.sql) with the declared inputs.

## Display metadata

```yaml
level: detail
format: table
columns:
- name: upid
  label: upid
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
- name: state_covered_ns
  label: state_covered_ns
  type: duration
  unit: ns
  hidden: true
- name: state_evidence
  label: state_evidence
  type: string
  hidden: true
- name: uninterruptible_ms
  label: uninterruptible_ms
  type: number
  hidden: true
- name: runnable_preempted_ms
  label: runnable_preempted_ms
  type: number
  hidden: true
- name: other_state_ms
  label: other_state_ms
  type: number
  hidden: true
- name: thread_name
  label: 线程
  type: string
- name: process_name
  label: 进程
  type: string
- name: is_main_thread
  label: 主线程
  type: boolean
- name: running_ms
  label: 运行时间
  type: duration
  format: duration_ms
- name: runnable_ms
  label: 等待调度
  type: duration
  format: duration_ms
- name: sleeping_ms
  label: 休眠时间
  type: duration
  format: duration_ms
- name: max_runnable_ms
  label: 最大等待
  type: duration
  format: duration_ms
- name: long_runnable_count
  label: 长等待次数
  type: number
```
