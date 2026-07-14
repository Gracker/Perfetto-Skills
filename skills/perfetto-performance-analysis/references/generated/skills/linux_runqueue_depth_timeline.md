GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_runqueue_depth_timeline.skill.yaml
Source SHA-256: 97534c690220e660274868201d0a31f13496a46e688ce0b95a08558ad75197af
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Linux Runqueue 深度时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_runqueue_depth_timeline
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Linux Runqueue 深度时间线
description: 基于 sched.thread_level_parallelism stdlib 输出 runnable thread count 时间线和高压区间
icon: timeline
tags:
- linux
- runqueue
- runnable
- scheduler
- cpu_contention
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - runqueue
  - runnable 线程数
  - CPU 队列
  - 调度压力
  en:
  - runqueue
  - runnable thread count
  - cpu queue
  - scheduling pressure
patterns:
- .*(runqueue|runnable).*(深度|线程数|压力).*
- .*(runqueue|runnable).*(depth|count|pressure).*
```

## Prerequisites

```yaml
required_tables:
- thread_state
modules:
- sched.thread_level_parallelism
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: pressure_threshold
  type: number
  required: false
  description: 高压 runnable 线程数阈值，默认 4
```

## Ordered execution

### Runqueue 压力汇总

- ID: `runqueue_pressure_summary`
- Type: `atomic`
- SQL: [`../sql/linux_runqueue_depth_timeline/runqueue_pressure_summary.sql`](../sql/linux_runqueue_depth_timeline/runqueue_pressure_summary.sql)

```yaml
id: runqueue_pressure_summary
type: atomic
display:
  level: summary
  layer: overview
  title: Runqueue 压力汇总
  columns:
  - name: samples
    label: 样本数
    type: number
    format: compact
  - name: avg_runnable
    label: 平均Runnable
    type: number
  - name: p95_runnable
    label: P95Runnable
    type: number
  - name: max_runnable
    label: 最大Runnable
    type: number
  - name: pressure_samples
    label: 高压样本
    type: number
    format: compact
save_as: runqueue_pressure_summary
```
### Runqueue 高压点

- ID: `runqueue_pressure_windows`
- Type: `atomic`
- SQL: [`../sql/linux_runqueue_depth_timeline/runqueue_pressure_windows.sql`](../sql/linux_runqueue_depth_timeline/runqueue_pressure_windows.sql)

```yaml
id: runqueue_pressure_windows
type: atomic
display:
  level: detail
  layer: list
  title: Runqueue 高压时间点
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: runnable_thread_count
    label: Runnable线程数
    type: number
save_as: runqueue_pressure_windows
```
## Output and evidence contract

```yaml
format: structured
```
