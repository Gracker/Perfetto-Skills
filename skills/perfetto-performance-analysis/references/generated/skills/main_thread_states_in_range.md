GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_states_in_range.skill.yaml
Source SHA-256: 9dff50424647c05fa5494e804e49bc18338d552e3b39edb6edca6cbb4c53e3e2
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 主线程状态分布 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: main_thread_states_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 主线程状态分布 (区间)
description: 统计区间内主线程状态、阻塞函数与占比
icon: timeline
tags:
- main_thread
- state
- blocking
- sched
- atomic
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 目标进程名；匹配精确进程或 name:* 子进程
- name: upid
  type: integer
  required: false
  default: 0
  description: Trace 内唯一进程 ID；优先用于精确进程隔离
- name: pid
  type: integer
  required: false
  default: 0
  description: 进程 ID；无 upid 时作为降级匹配
- name: top_k
  type: integer
  required: false
  description: 返回 TopK 条目，默认 10
```

## Query

Run [`../sql/main_thread_states_in_range/query.sql`](../sql/main_thread_states_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: deep
title: 主线程状态分布
columns:
- name: state
  label: 状态
  type: string
- name: state_desc
  label: 状态说明
  type: string
- name: blocked_function
  label: 阻塞函数
  type: string
  format: code
- name: io_wait
  label: io_wait
  type: number
  format: compact
- name: evidence_strength
  label: 证据强度
  type: string
- name: total_dur_ms
  label: 总耗时
  type: duration
  format: duration_ms
- name: pct
  label: 区间占比
  type: percentage
  format: percentage
- name: count
  label: 次数
  type: number
  format: compact
```
