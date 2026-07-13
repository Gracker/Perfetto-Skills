GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gc_events_in_range.skill.yaml
Source SHA-256: 1b3a5a7f2e13ed61dddef00d1d78f2fb1032e35ed9bcccb6559913ea8ca73d11
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# GC 事件查询

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gc_events_in_range
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: GC 事件查询
description: 查询 GC 事件并分类，供后续分析步骤复用
icon: memory
tags:
- gc
- memory
- events
- atomic
```

## Prerequisites

```yaml
modules:
- android.garbage_collection
```

## Inputs

```yaml
- name: package
  type: string
  required: true
  description: 应用包名
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳（纳秒，可选）
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳（纳秒，可选）
```

## Query

Run [`../sql/gc_events_in_range/query.sql`](../sql/gc_events_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: GC 事件
columns:
- name: ts
  label: 时间戳
  type: timestamp
  clickAction: navigate_timeline
- name: dur
  label: 持续时间
  type: duration
  format: duration_ms
  unit: ns
- name: gc_name
  label: GC 名称
  type: string
- name: gc_type
  label: GC 类型
  type: string
- name: thread_name
  label: 线程
  type: string
- name: is_main_thread
  label: 主线程
  type: number
- name: reclaimed_mb
  label: 回收(MB)
  type: number
- name: gc_running_dur
  label: GC运行时间
  type: duration
  format: duration_ms
  unit: ns
```
