GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_perf_counter_hotspots.skill.yaml
Source SHA-256: a45de9aedc3fc4f3cf6cf9056e2e50d0de44ab20831abdaa17a1351352564370
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# Linux Perf Counter Hotspots

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_perf_counter_hotspots
version: '1.0'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Linux Perf Counter Hotspots
description: 基于 linux.perf.counters stdlib 汇总 perf sample counter 热点；无 PMU 数据时返回空
icon: speed
tags:
- linux
- perf
- pmu
- counters
- cache_miss
- branch
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - PMU
  - perf counter
  - cache miss
  - branch miss
  - 缓存未命中
  - 分支预测
  en:
  - pmu
  - perf counter
  - cache miss
  - branch miss
  - branch mispredict
patterns:
- .*(PMU|perf|cache miss|branch).*(热点|统计|分析).*
- .*(pmu|perf|cache|branch).*(hotspot|counter|miss).*
```

## Prerequisites

```yaml
optional_tables:
- track
modules:
- linux.perf.counters
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

### Perf Counter 热点

- ID: `perf_counter_hotspots`
- Type: `atomic`
- SQL: [`../sql/linux_perf_counter_hotspots/perf_counter_hotspots.sql`](../sql/linux_perf_counter_hotspots/perf_counter_hotspots.sql)

```yaml
id: perf_counter_hotspots
type: atomic
display:
  level: detail
  layer: list
  title: Linux Perf Counter Hotspots
  columns:
  - name: counter_name
    label: Counter
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: sample_count
    label: 样本数
    type: number
    format: compact
  - name: total_counter_value
    label: 累计值
    type: number
    format: compact
  - name: avg_counter_value
    label: 平均值
    type: number
    format: compact
save_as: perf_counter_hotspots
```
## Output and evidence contract

```yaml
format: structured
```
