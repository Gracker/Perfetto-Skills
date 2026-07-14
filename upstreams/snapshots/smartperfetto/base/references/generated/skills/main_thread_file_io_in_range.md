GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/main_thread_file_io_in_range.skill.yaml
Source SHA-256: e96c4772975c5a3a1f3a11164d8a61b17275ce0526269a589687536fbf290c6f
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
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
description: 统计区间内主线程文件/SQLite 命名切片耗时；命名切片是线索，不单独证明底层存储阻塞
icon: folder
tags:
- main_thread
- io
- file_io
- sqlite
- database
- startup
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 主线程 IO
  - 文件 IO
  - SQLite
  - 数据库切片
  - 磁盘访问
  en:
  - main thread IO
  - file IO
  - SQLite
  - database slice
  - disk access
patterns:
- (?i)(main thread|主线程).*(file|sqlite|database|io|文件|数据库)
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
