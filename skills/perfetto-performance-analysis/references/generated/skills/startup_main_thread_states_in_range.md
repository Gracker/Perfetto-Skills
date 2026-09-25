GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_main_thread_states_in_range.skill.yaml
Source SHA-256: 47e6b6e9b545b31fe26b0e29c8e3ab63e959a93d20dcd35c28f09facb3963b61
Source commit: 459063305709d69ae0a322371bba3f506c41c62c
# 启动主线程状态分布 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_main_thread_states_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动主线程状态分布 (区间)
description: 统计启动阶段主线程 Running/Runnable/Blocked 状态占比
icon: timeline
tags:
- startup
- main_thread
- state
- sched
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

Run [`../sql/startup_main_thread_states_in_range/query.sql`](../sql/startup_main_thread_states_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 启动期间主线程状态
columns:
- name: state
  label: 状态
  type: string
- name: state_desc
  label: 状态说明
  type: string
- name: total_dur_ms
  label: 总耗时
  type: duration
  format: duration_ms
  unit: ms
- name: percent
  label: 占比
  type: percentage
  format: percentage
- name: count
  label: 次数
  type: number
  format: compact
- name: io_wait
  label: io_wait
  type: number
  format: compact
- name: evidence_strength
  label: 证据强度
  type: string
- name: blocked_functions
  label: 阻塞函数
  type: string
  format: truncate
```
