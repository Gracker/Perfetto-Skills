GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_process_rss_swap_timeline.skill.yaml
Source SHA-256: f53d47d4593d8d3df74a9e33510f95984897d677cb882cd2a9d39494e4432c1f
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# Linux 进程 RSS/Swap 时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_process_rss_swap_timeline
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: Linux 进程 RSS/Swap 时间线
description: 基于 linux.memory.process stdlib 汇总进程 RSS、anon RSS 和 swap 峰值
icon: memory
tags:
- linux
- memory
- rss
- swap
- process
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - RSS
  - swap
  - 进程内存
  - Linux 内存
  - 常驻内存
  en:
  - rss
  - swap
  - process memory
  - linux memory
  - resident set
patterns:
- .*(RSS|swap|常驻内存|进程内存).*
- .*(rss|swap|resident|process memory).*
```

## Prerequisites

```yaml
modules:
- linux.memory.process
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### RSS/Swap 峰值

- ID: `rss_swap_peaks`
- Type: `atomic`
- SQL: [`../sql/linux_process_rss_swap_timeline/rss_swap_peaks.sql`](../sql/linux_process_rss_swap_timeline/rss_swap_peaks.sql)

```yaml
id: rss_swap_peaks
type: atomic
display:
  level: summary
  layer: overview
  title: 进程 RSS/Swap 峰值
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: samples
    label: 样本数
    type: number
    format: compact
  - name: max_rss_mb
    label: RSS峰值
    type: number
  - name: max_anon_swap_mb
    label: Anon+Swap峰值
    type: number
  - name: max_swap_mb
    label: Swap峰值
    type: number
save_as: rss_swap_peaks
```
## Output and evidence contract

```yaml
format: structured
```
