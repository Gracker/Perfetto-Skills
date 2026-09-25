GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/android_process_state_residency.skill.yaml
Source SHA-256: f785279fb41abf9e40451b7089d02655c17180229724e8a28759af866c6347cf
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# 进程状态驻留与切换

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: android_process_state_residency
version: '1.0'
type: atomic
category: memory
tier: B
```

## Metadata

```yaml
display_name: 进程状态驻留与切换
description: Framework 进程状态（TOP/前台服务/CACHED 等）的驻留时长、切换序列与最后观测状态；用于 LMK、后台与内存压力分析，旧 trace processor 显式降级
icon: swap_vert
tags:
- memory
- lmk
- process_state
- background
- oom_adj
- framework
```

## Triggers

```yaml
keywords:
  zh:
  - 进程状态
  - process state
  - 后台进程
  - cached 进程
  - 进程优先级
  - 被杀前状态
  en:
  - process state
  - proc state
  - cached process
  - background process
  - process importance
patterns:
- .*(process state|proc state|进程状态).*
- .*(cached|后台).*(进程|process).*
```

## Prerequisites

```yaml
modules:
- android.process_state
```

## Inputs

```yaml
- name: process_name
  type: string
  required: false
  description: 目标进程名或包名（精确或 name:* 子进程）；留空返回全部有进程状态数据的进程
- name: upid
  type: integer
  required: false
  description: 可选的稳定进程身份
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；驻留时长按窗口裁剪
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: max_rows
  type: integer
  required: false
  default: 200
  description: 状态切换序列最多返回的行数
```

## Ordered execution

### 进程状态能力检查

- ID: `process_state_capability`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_capability.sql`](../sql/android_process_state_residency/process_state_capability.sql)

```yaml
id: process_state_capability
type: atomic
display:
  level: detail
  layer: overview
  title: 进程状态（android.process_state）能力
  columns:
  - name: runtime_has_process_state_table
    label: Runtime 有解析表
    type: number
  - name: runtime_has_process_state_module
    label: Runtime 有 stdlib 模块
    type: number
  - name: status
    label: 状态
    type: string
save_as: process_state_capability
```
### 进程状态数据检查

- ID: `process_state_data`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_data.sql`](../sql/android_process_state_residency/process_state_data.sql)

```yaml
id: process_state_data
type: atomic
optional: true
condition: process_state_capability.data[0]?.status === 'runtime_supported'
display:
  level: detail
  layer: overview
  title: 进程状态数据
  columns:
  - name: state_event_count
    label: 状态事件数
    type: number
  - name: process_count
    label: 进程数
    type: number
  - name: matched_process_count
    label: 匹配目标的进程数
    type: number
  - name: status
    label: 状态
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_data
```
### 进程状态驻留

- ID: `process_state_residency`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_residency.sql`](../sql/android_process_state_residency/process_state_residency.sql)

```yaml
id: process_state_residency
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: key
  layer: list
  title: 进程状态驻留（存活时间内，按窗口裁剪）
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: state
    label: 状态
    type: string
  - name: state_rank
    label: 重要性序
    type: number
  - name: residency_ms
    label: 驻留时长
    type: duration
    format: duration_ms
    unit: ms
  - name: residency_pct
    label: 占存活时间
    type: percentage
    format: percentage
  - name: interval_count
    label: 进入次数
    type: number
  - name: first_entered_ts
    label: 首次进入
    type: timestamp
    unit: ns
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_residency
```
### 进程状态切换

- ID: `process_state_transitions`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_transitions.sql`](../sql/android_process_state_residency/process_state_transitions.sql)

```yaml
id: process_state_transitions
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: detail
  layer: list
  title: 进程状态切换序列
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: ts
    label: 切换时间
    type: timestamp
    unit: ns
  - name: prev_state
    label: 原状态
    type: string
  - name: state
    label: 新状态
    type: string
  - name: prev_state_ms
    label: 原状态停留
    type: duration
    format: duration_ms
    unit: ms
  - name: reason
    label: OomAdjuster 原因
    type: string
  - name: lifecycle
    label: 生命周期
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_transitions
```
### 最后观测状态

- ID: `process_state_last_observed`
- Type: `atomic`
- SQL: [`../sql/android_process_state_residency/process_state_last_observed.sql`](../sql/android_process_state_residency/process_state_last_observed.sql)

```yaml
id: process_state_last_observed
type: atomic
optional: true
condition: process_state_data.data[0]?.status === 'available'
display:
  level: key
  layer: list
  title: 每个进程最后一次观测到的状态
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: last_state
    label: 最后状态
    type: string
  - name: entered_ts
    label: 进入时间
    type: timestamp
    unit: ns
  - name: process_end_ts
    label: 进程结束时间
    type: timestamp
    unit: ns
  - name: lifecycle
    label: 生命周期
    type: string
sql_fragments:
- fragments/process_state_scoped_intervals.sql
save_as: process_state_last_observed
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: process_state_capability
  description: 'Runtime support: runtime_lacks_process_state on trace processors up to v58.2, which cannot read this data
    at all'
- name: process_state_data
  description: Whether the trace carries android.process_state snapshot or state-change events, and whether any belong to
    the requested process
- name: process_state_residency
  description: Per process and framework state, time spent while alive within the window and its share of alive time; EXITED/NONEXISTENT
    markers are excluded
- name: process_state_transitions
  description: Ordered state changes with the previous state's duration and the OomAdjuster reason; initial_state rows are
    backfilled from snapshots
- name: process_state_last_observed
  description: Last alive state per process and whether the process ended, for comparing with LMK kills and oom_score_adj
```
