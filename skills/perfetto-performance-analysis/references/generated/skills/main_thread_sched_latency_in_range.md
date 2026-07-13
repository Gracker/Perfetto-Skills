GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_sched_latency_in_range.skill.yaml
Source SHA-256: de053b0fa4190314df852b3a55b169077626cae09d319365cdaff98c5ec3ad1e
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 主线程调度延迟 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: main_thread_sched_latency_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 主线程调度延迟 (区间)
description: 统计主线程 Runnable 等待时间分布
icon: schedule
tags:
- sched
- latency
- main_thread
- atomic
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
  description: 目标应用包名（支持 GLOB）
```

## Query

Run [`../sql/main_thread_sched_latency_in_range/query.sql`](../sql/main_thread_sched_latency_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 主线程调度延迟
columns:
- name: thread_name
  label: 线程
  type: string
- name: runnable_count
  label: 等待次数
  type: number
- name: total_runnable_ms
  label: 总等待
  type: duration
  format: duration_ms
- name: max_latency_ms
  label: 最大延迟
  type: duration
  format: duration_ms
- name: avg_latency_ms
  label: 平均延迟
  type: duration
  format: duration_ms
- name: long_wait_count
  label: '>2ms 次数'
  type: number
- name: severe_count
  label: '>8ms 次数'
  type: number
```
