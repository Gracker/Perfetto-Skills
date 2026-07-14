GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/scheduling_analysis.skill.yaml
Source SHA-256: 1e143b06981a9c0792d2263ba7c2d42a08a87a69f9257a6af7305abdc3080cab
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
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
