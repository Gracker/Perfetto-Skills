GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/sched_latency_in_range.skill.yaml
Source SHA-256: c137f26b45fa0a1c7178145e5afef3f68651016fdbdb68756dd28dab7c0d0de9
Source commit: 00559cb4068232b511e24c614eadcad0b122bdc5
# 调度延迟分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: sched_latency_in_range
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 调度延迟分析
description: 分析线程调度等待时间分布，检测 CPU 争抢
icon: schedule
tags:
- sched
- latency
- kernel
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
  description: 目标进程名（支持 GLOB 匹配）
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/sched_latency_in_range/query.sql`](../sql/sched_latency_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: deep
title: 调度延迟
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
- name: runnable_preempted_ms
  label: runnable_preempted_ms
  type: number
  hidden: true
- name: right_censored_count
  label: right_censored_count
  type: number
  hidden: true
- name: latency_evidence
  label: latency_evidence
  type: string
  hidden: true
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
  label: '>2ms次数'
  type: number
```
