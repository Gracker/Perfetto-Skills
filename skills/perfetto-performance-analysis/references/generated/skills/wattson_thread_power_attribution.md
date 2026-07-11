GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/wattson_thread_power_attribution.skill.yaml
Source SHA-256: 388c3628de80519709306fc275669effa48f3fe8e2cca8487bbc180070080e9a
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 线程功耗归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wattson_thread_power_attribution
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: 线程功耗归因
description: 按线程归因 CPU 能耗（mWs）—— 排查偷电进程
icon: developer_board
tags:
- power
- wattson
- thread
- attribution
- atomic
```

## Prerequisites

```yaml
modules:
- wattson.aggregation
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标包名或进程名前缀 GLOB（可选）
- name: process_name
  type: string
  required: false
  description: 目标进程名 GLOB（可选）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: top_n
  type: number
  required: false
  default: 30
  description: 返回前 N 个线程
```

## Ordered execution

### 线程级 CPU 功耗

- ID: `thread_attribution`
- Type: `atomic`
- SQL: [`../sql/wattson_thread_power_attribution/thread_attribution.sql`](../sql/wattson_thread_power_attribution/thread_attribution.sql)

```yaml
id: thread_attribution
type: atomic
display:
  level: detail
  layer: list
  title: Top 耗电线程（按 CPU mWs）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: total_cpu_mws
    label: 总能耗(mWs)
    type: number
    format: compact
  - name: energy_mwh
    label: 能耗(mWh)
    type: number
    format: compact
  - name: avg_cpu_mw
    label: 平均功率(mW)
    type: number
    format: compact
  - name: source_level
    label: 数据来源
    type: string
```
