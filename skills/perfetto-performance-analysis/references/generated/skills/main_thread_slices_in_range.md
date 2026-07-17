GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_slices_in_range.skill.yaml
Source SHA-256: 92c26f5fe09128479cfc14d876cfbcd7f894ba46ddf9121de2565125973321c0
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# 主线程切片热点 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: main_thread_slices_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 主线程切片热点 (区间)
description: 统计区间内主线程切片耗时分布
icon: view_timeline
tags:
- main_thread
- slice
- startup
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
  description: 目标应用进程名；匹配精确进程或 name:* 子进程
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
- name: min_dur_ns
  type: integer
  required: false
  description: 最小切片时长阈值(ns)，默认 1ms
- name: top_k
  type: integer
  required: false
  description: 返回 TopK 条目，默认 10
```

## Query

Run [`../sql/main_thread_slices_in_range/query.sql`](../sql/main_thread_slices_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: deep
title: 主线程耗时操作 Top10
columns:
- name: slice_name
  label: 切片名
  type: string
- name: count
  label: 次数
  type: number
  format: compact
- name: total_ms
  label: 总耗时(wall)
  type: duration
  format: duration_ms
- name: self_ms
  label: 自身耗时
  type: duration
  format: duration_ms
- name: avg_ms
  label: 平均耗时
  type: duration
  format: duration_ms
- name: max_ms
  label: 最大耗时
  type: duration
  format: duration_ms
- name: percent
  label: 区间占比(wall)
  type: percentage
  format: percentage
- name: self_percent
  label: 区间占比(self)
  type: percentage
  format: percentage
```
