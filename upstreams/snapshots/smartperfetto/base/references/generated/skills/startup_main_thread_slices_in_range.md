GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_main_thread_slices_in_range.skill.yaml
Source SHA-256: fd120947d2d16e6e858b124fafe6e76d0e738555ed0764fc8d9d895a36bb6d10
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49
# 启动主线程切片热点 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_main_thread_slices_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 启动主线程切片热点 (区间)
description: 统计启动阶段主线程切片热点
icon: view_timeline
tags:
- startup
- main_thread
- slice
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
- name: min_dur_ns
  type: integer
  required: false
- name: top_k
  type: integer
  required: false
```

## Query

Run [`../sql/startup_main_thread_slices_in_range/query.sql`](../sql/startup_main_thread_slices_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: overview
title: 主线程耗时操作 Top15
columns:
- name: slice_name
  label: 操作名称
  type: string
- name: thread_name
  label: 线程
  type: string
- name: count
  label: 次数
  type: number
  format: compact
- name: total_dur_ms
  label: 总耗时(wall)
  type: duration
  format: duration_ms
- name: self_dur_ms
  label: 自身耗时
  type: duration
  format: duration_ms
- name: avg_dur_ms
  label: 平均耗时
  type: duration
  format: duration_ms
- name: max_dur_ms
  label: 最大耗时
  type: duration
  format: duration_ms
- name: percent_of_startup
  label: 启动占比(wall)
  type: percentage
  format: percentage
- name: self_percent
  label: 启动占比(self)
  type: percentage
  format: percentage
- name: startup_type
  label: 启动类型
  type: string
```
