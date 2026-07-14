GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_sched_latency_distribution.skill.yaml
Source SHA-256: b193794805d2765d8923aeb693fe88709520ebe0d0b3c9ff5eb44a2e0a9afe73
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Linux 调度延迟分布

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_sched_latency_distribution
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Linux 调度延迟分布
description: 基于 sched.latency stdlib 汇总 Runnable→Running 调度等待分布
icon: schedule
tags:
- linux
- sched
- latency
- runnable
- kernel
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 调度延迟
  - Runnable 等待
  - runqueue
  - CPU 争抢
  - Linux 调度
  en:
  - sched latency
  - runnable latency
  - runqueue
  - cpu contention
  - linux scheduler
patterns:
- .*(调度|Runnable|runqueue).*(延迟|等待|争抢).*
- .*(sched|runnable|runqueue).*(latency|wait|contention).*
```

## Prerequisites

```yaml
required_tables:
- thread
- process
- thread_state
modules:
- sched.latency
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### 调度延迟分布

- ID: `sched_latency_distribution`
- Type: `atomic`
- SQL: [`../sql/linux_sched_latency_distribution/sched_latency_distribution.sql`](../sql/linux_sched_latency_distribution/sched_latency_distribution.sql)

```yaml
id: sched_latency_distribution
type: atomic
display:
  level: summary
  layer: overview
  title: Linux 调度延迟分布
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: runnable_count
    label: 等待次数
    type: number
    format: compact
  - name: total_latency_ms
    label: 总等待
    type: duration
    format: duration_ms
  - name: avg_latency_ms
    label: 平均等待
    type: duration
    format: duration_ms
  - name: p95_latency_ms
    label: P95等待
    type: duration
    format: duration_ms
  - name: max_latency_ms
    label: 最大等待
    type: duration
    format: duration_ms
  - name: severe_waits
    label: '>8ms'
    type: number
    format: compact
save_as: sched_latency_distribution
```
## Output and evidence contract

```yaml
format: structured
```
