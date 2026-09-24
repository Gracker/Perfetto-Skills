GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_workload_attribution_in_range.skill.yaml
Source SHA-256: deda79ad447ced6323b09d92a57c1031fe27378e197e1e8cb0845a30efca29e8
Source commit: 751cebf0e6a67b946b26aa0abfb12d4a0a5ac8ad
# 窗口 CPU 负载归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_workload_attribution_in_range
version: '1.0'
type: atomic
category: cpu
tier: A
```

## Metadata

```yaml
display_name: 窗口 CPU 负载归因
description: 在指定窗口内按线程聚合运行时长、核心分布与频率加权工作量；仅为观测，不构成因果
icon: insights
tags:
- cpu
- sched
- attribution
- workload
- range
- evidence
```

## Triggers

```yaml
keywords:
  zh:
  - 窗口 CPU 负载
  - 谁在跑
  - CPU 归因
  - 负载归因
  en:
  - cpu workload attribution
  - who was running
  - cpu attribution
patterns:
- .*(窗口|区间).*(CPU|负载).*(归因|谁).*
- .*cpu.*workload.*attribution.*
```

## Prerequisites

```yaml
required_tables:
- sched_slice
- thread
- process
modules:
- linux.cpu.frequency
- intervals.intersect
- android.process_metadata
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 窗口起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 窗口结束时间戳(ns)
- name: package
  type: string
  required: false
  description: 目标包名/进程名；用于标注 actor_class=target_app
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；package 为空时使用
- name: top_n
  type: number
  required: false
  default: 30
  description: 按工作量返回前 N 个线程
```

## Ordered execution

### 线程级 CPU 负载归因

- ID: `workload_by_thread`
- Type: `atomic`
- SQL: [`../sql/cpu_workload_attribution_in_range/workload_by_thread.sql`](../sql/cpu_workload_attribution_in_range/workload_by_thread.sql)

```yaml
id: workload_by_thread
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/system_cpu_frequency_spans.sql
- fragments/actor_class_labels.sql
display:
  level: summary
  layer: list
  title: 窗口内 CPU 负载归因（观测，非因果）
  columns:
  - name: window_id
    label: window_id
    type: number
    hidden: true
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_dur_ns
    label: 窗口时长
    type: duration
    unit: ns
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: pid
    label: pid
    type: number
    hidden: true
  - name: tid
    label: tid
    type: number
    hidden: true
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: actor_class
    label: 角色
    type: string
  - name: actor_class_basis
    label: 角色判定依据
    type: string
  - name: running_ns
    label: 运行时长
    type: duration
    unit: ns
  - name: running_pct_of_window
    label: 窗口 CPU 占用
    type: percentage
  - name: big_running_ns
    label: 大核运行
    type: duration
    unit: ns
  - name: medium_running_ns
    label: 中核运行
    type: duration
    unit: ns
  - name: little_running_ns
    label: 小核运行
    type: duration
    unit: ns
  - name: unknown_core_running_ns
    label: 未知核型运行
    type: duration
    unit: ns
  - name: freq_weighted_work_mhz_ms
    label: 频率加权工作量
    type: number
  - name: share_of_total_work_pct
    label: 工作量占比
    type: percentage
  - name: sched_slice_count
    label: 调度片数
    type: number
  - name: freq_covered_ns
    label: 频率覆盖
    type: duration
    unit: ns
  - name: frequency_evidence
    label: 频率证据
    type: string
  - name: sched_evidence
    label: 调度证据
    type: string
  - name: cpu_count
    label: CPU 数
    type: number
    hidden: true
  - name: window_capacity_ns
    label: window_capacity_ns
    type: duration
    unit: ns
    hidden: true
  - name: normalization_basis
    label: 归一化依据
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有可归因的非 idle 调度片；确认 trace 含 ftrace sched/sched_switch 且窗口落在数据范围内。
save_as: workload_by_thread
```
### 窗口负载汇总

- ID: `workload_summary`
- Type: `atomic`
- SQL: [`../sql/cpu_workload_attribution_in_range/workload_summary.sql`](../sql/cpu_workload_attribution_in_range/workload_summary.sql)

```yaml
id: workload_summary
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/actor_class_labels.sql
display:
  level: summary
  layer: overview
  title: 窗口负载汇总（按角色 / 按核型）
  columns:
  - name: window_start_ts
    label: window_start_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_end_ts
    label: window_end_ts
    type: timestamp
    unit: ns
    hidden: true
  - name: window_dur_ns
    label: 窗口时长
    type: duration
    unit: ns
  - name: breakdown_kind
    label: 维度
    type: string
  - name: breakdown_key
    label: 分组
    type: string
  - name: running_ns
    label: 运行时长
    type: duration
    unit: ns
  - name: busy_pct
    label: 占用率
    type: percentage
  - name: thread_count
    label: 线程数
    type: number
  - name: denominator_basis
    label: 分母依据
    type: string
  - name: sched_evidence
    label: 调度证据
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内无调度数据。
save_as: workload_summary
```
## Output and evidence contract

```yaml
format: structured
```
