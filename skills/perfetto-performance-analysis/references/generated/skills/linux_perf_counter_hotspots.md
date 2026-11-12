GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/linux_perf_counter_hotspots.skill.yaml
Source SHA-256: c86639e8f7f1629839d6b73bc1369754c96e74ca1f44c2557f44df90717faf82
# Linux Perf Counter Hotspots

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: linux_perf_counter_hotspots
version: '1.2'
type: atomic
category: kernel
tier: B
```

## Metadata

```yaml
display_name: Linux Perf Counter Hotspots
description: 按采样周期差值汇总 linux.perf 硬件计数器热点，并按进程给出 IPC、cache miss 比例和 MPKI；无 PMU 数据时返回空
icon: speed
tags:
- linux
- perf
- pmu
- cpu
- hotspot
- counters
- cache_miss
- branch
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - CPU
  - CPU热点
  - 热点
  - PMU
  - perf counter
  - cache miss
  - branch miss
  - 缓存未命中
  - 分支预测
  - IPC
  - 指令周期
  en:
  - cpu
  - cpu hotspot
  - hotspot
  - pmu
  - perf counter
  - cache miss
  - branch miss
  - branch mispredict
  - ipc
  - instructions per cycle
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
- name: upid
  type: integer
  required: false
  description: 目标进程实例 UPID；优先于进程名，仍须通过身份门禁
- name: package
  type: string
  required: false
  description: 目标进程名（精确匹配，含 name:* 子进程）
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
process_scope:
  role: target
  binding: native_upid
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
  - name: total_counter_delta
    label: 事件总数
    label_i18n:
      en: Total Events
    type: number
    format: compact
    semantics: Sum of per-sample deltas of the cumulative per-CPU counter track, attributed to the sampled thread.
  - name: avg_counter_delta
    label: 每样本事件数
    label_i18n:
      en: Events per Sample
    type: number
    format: compact
    semantics: Mean delta per sample, roughly the configured sample period; not an intensity measure on its own.
sql_fragments:
- fragments/linux_perf_counter_deltas.sql
save_as: perf_counter_hotspots
```
### PMU 派生比值（按进程）

- ID: `perf_counter_ratios`
- Type: `atomic`
- SQL: [`../sql/linux_perf_counter_hotspots/perf_counter_ratios.sql`](../sql/linux_perf_counter_hotspots/perf_counter_ratios.sql)

```yaml
id: perf_counter_ratios
type: atomic
process_scope:
  role: target
  binding: native_upid
display:
  level: summary
  layer: overview
  title: PMU 派生比值（按进程）
  title_i18n:
    en: PMU Derived Ratios by Process
  row_semantics: per_entity
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: samples
    label: 样本数
    type: number
    format: compact
  - name: cycles_share_pct
    label: cycles 占比
    type: percentage
    format: percentage
    semantics: This process's share of all sampled cpu-cycles in the window across every process, even when filtered.
  - name: cycles_m
    label: cycles(百万)
    label_i18n:
      en: Cycles (M)
    type: number
  - name: instructions_m
    label: instructions(百万)
    label_i18n:
      en: Instructions (M)
    type: number
  - name: ipc
    label: IPC
    type: number
    semantics: instructions / cpu-cycles from per-sample deltas. Each hardware counter is sampled in its own perf session,
      so this is a sampling estimate, not an exact per-instruction measurement.
  - name: cache_references_m
    label: cache-references(百万)
    label_i18n:
      en: Cache References (M)
    type: number
  - name: cache_misses_m
    label: cache-misses(百万)
    label_i18n:
      en: Cache Misses (M)
    type: number
  - name: cache_miss_pct
    label: cache miss 比例
    label_i18n:
      en: Cache Miss Ratio
    type: percentage
    format: percentage
    semantics: cache-misses / cache-references. These are generic perf events; which cache level they count is decided by
      the CPU PMU driver, so do not name a specific L1/L2/LLC level from this alone.
  - name: mpki
    label: MPKI
    type: number
    semantics: cache-misses per 1000 instructions.
sql_fragments:
- fragments/linux_perf_counter_deltas.sql
save_as: perf_counter_ratios
```
## Output and evidence contract

```yaml
format: structured
```
