GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/longest_process_slices.skill.yaml
Source SHA-256: afd2f8caa3379888693e359840046ddb1c854202cdfe90578fc67ddd9a4916a8
Source commit: 014f85f56ddbac288cbf30faed548086506f968a
# 最长进程 Slice

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: longest_process_slices
version: '1.0'
type: atomic
category: system
tier: B
```

## Metadata

```yaml
display_name: 最长进程 Slice
description: 按时间窗重叠时长列出最长的 process/thread track slice
icon: hourglass_top
tags:
- system
- sanity
- trace
- slice
- process
- thread
- duration
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 最长 slice
  - 最长进程 slice
  - 耗时最长 slice
  - top slice
  en:
  - longest slices
  - longest process slices
  - top slices
  - slice duration
patterns:
- .*(最长|耗时最长).*(slice|切片).*
- .*top[-_ ]*[0-9]+.*longest.*slices?.*
- .*longest.*process.*slices?.*
```

## Prerequisites

```yaml
required_tables:
- slice
- track
- thread_track
- thread
- process
- process_track
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)，默认 trace_start()
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)，默认 trace_end()
- name: max_rows
  type: integer
  required: false
  default: 20
  description: 返回行数，范围 1-100
```

## Query

Run [`../sql/longest_process_slices/query.sql`](../sql/longest_process_slices/query.sql) with the declared inputs.

## Display metadata

```yaml
level: detail
layer: list
title: 时间窗内最长 Slice
columns:
- name: ts
  label: 开始
  type: timestamp
  unit: ns
  clickAction: navigate_range
  durationColumn: dur_ns
- name: duration_ms
  label: 时长
  type: duration
  unit: ms
  format: duration_ms
- name: slice_name
  label: Slice
  type: string
  format: truncate
- name: process_name
  label: 进程
  type: string
  format: truncate
- name: thread_name
  label: 线程
  type: string
  format: truncate
- name: track_scope
  label: Track 范围
  type: string
  hidden: true
- name: dur_ns
  label: 时长(ns)
  type: duration
  unit: ns
  hidden: true
- name: slice_start_ts
  label: 原始Slice开始
  type: timestamp
  unit: ns
  hidden: true
- name: slice_id
  label: Slice ID
  type: number
  hidden: true
- name: slice_dur_ns
  label: 原始Slice时长
  type: duration
  unit: ns
  hidden: true
```
