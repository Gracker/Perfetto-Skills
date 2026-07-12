GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_file_io_in_range.skill.yaml
Source SHA-256: 445bb9c9c1c3650896f9bc8d15f7338b57a09c8a28bc3a844cc4be55ae7e6a13
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# 主线程文件 IO (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: main_thread_file_io_in_range
version: '1.0'
type: atomic
category: app_lifecycle
tier: B
```

## Metadata

```yaml
display_name: 主线程文件 IO (区间)
description: 统计区间内主线程文件 IO 相关切片耗时
icon: folder
tags:
- main_thread
- io
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
  description: 目标应用包名（支持 GLOB）
- name: min_dur_ns
  type: integer
  required: false
  description: 最小切片时长阈值(ns)，默认 0.5ms
- name: top_k
  type: integer
  required: false
  description: 返回 TopK 条目，默认 10
```

## Query

Run [`../sql/main_thread_file_io_in_range/query.sql`](../sql/main_thread_file_io_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: deep
title: 主线程文件 IO Top10
columns:
- name: io_slice
  label: IO 切片
  type: string
- name: count
  label: 次数
  type: number
  format: compact
- name: total_ms
  label: 总耗时
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
  label: 区间占比
  type: percentage
  format: percentage
```
