GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_thread_utilization_period.skill.yaml
Source SHA-256: 44ae1627a2ce3cfe119c52b3ba5f960828012d37c7afe1688dbe547eb2419d67
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# 线程 CPU 利用率（周期）

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_thread_utilization_period
version: '1.0'
type: atomic
category: cpu
tier: B
```

## Metadata

```yaml
display_name: 线程 CPU 利用率（周期）
description: 按线程统计 CPU 利用率，已频率归一化
icon: speed
tags:
- cpu
- thread
- utilization
- sched
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.utilization.thread
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
- name: top_n
  type: number
  required: false
  default: 30
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### 线程 CPU 利用率

- ID: `thread_util`
- Type: `atomic`
- SQL: [`../sql/cpu_thread_utilization_period/thread_util.sql`](../sql/cpu_thread_utilization_period/thread_util.sql)

```yaml
id: thread_util
type: atomic
display:
  level: detail
  layer: list
  title: Top 高利用率线程
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: utilization
    label: 利用率
    type: number
    format: compact
```
