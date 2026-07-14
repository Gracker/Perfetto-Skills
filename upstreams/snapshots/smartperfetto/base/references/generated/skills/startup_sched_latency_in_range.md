GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_sched_latency_in_range.skill.yaml
Source SHA-256: 868ae912f8997443ef08fdde6c3ceddbf4fb19eb4eff2517d5aec6048a897e81
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 启动调度延迟 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_sched_latency_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 启动调度延迟 (区间)
description: 统计启动阶段主线程 Runnable 等待时延
icon: schedule
tags:
- startup
- sched
- latency
- main_thread
- atomic
```

## Prerequisites

```yaml
modules:
- android.startup.startups
```

## Inputs

```yaml
- name: package
  type: string
  required: false
- name: startup_id
  type: integer
  required: false
- name: startup_type
  type: string
  required: false
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Query

Run [`../sql/startup_sched_latency_in_range/query.sql`](../sql/startup_sched_latency_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 启动期间调度延迟
columns:
- name: state
  label: 状态
  type: string
- name: count
  label: 次数
  type: number
  format: compact
- name: total_wait_ms
  label: 总等待
  type: duration
  format: duration_ms
- name: avg_wait_ms
  label: 平均等待
  type: duration
  format: duration_ms
- name: max_wait_ms
  label: 最大等待
  type: duration
  format: duration_ms
- name: severe_delays
  label: 严重延迟次数
  type: number
```
