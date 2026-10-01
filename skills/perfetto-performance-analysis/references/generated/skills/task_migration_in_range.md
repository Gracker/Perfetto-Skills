GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/task_migration_in_range.skill.yaml
Source SHA-256: 945999d90e633d652a979f3d0d4e74b2940c60ed1ab512858532afba2c310b4b
# 任务迁移分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: task_migration_in_range
version: '2.0'
type: composite
category: kernel
tier: B
```

## Metadata

```yaml
display_name: 任务迁移分析
description: 分析线程在大小核之间的迁移频率（动态拓扑检测）
icon: swap_horiz
tags:
- sched
- migration
- kernel
- composite
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
  description: 目标进程名（精确匹配，含 name:* 子进程）
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Ordered execution

### 初始化 CPU 拓扑

- ID: `init_cpu_topology`
- Type: `skill`

```yaml
id: init_cpu_topology
type: skill
skill: cpu_topology_view
display:
  level: hidden
optional: true
```
### 大小核迁移分析

- ID: `migration_analysis`
- Type: `atomic`
- SQL: [`../sql/task_migration_in_range/migration_analysis.sql`](../sql/task_migration_in_range/migration_analysis.sql)

```yaml
id: migration_analysis
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: 大小核迁移
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
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: utid
    label: utid
    type: number
    hidden: true
  - name: tid
    label: tid
    type: number
    hidden: true
  - name: migration_evidence
    label: migration_evidence
    type: string
    hidden: true
  - name: thread_name
    label: 线程
    type: string
  - name: migration_count
    label: 迁移次数
    type: number
  - name: big_to_little
    label: 大→小
    type: number
  - name: little_to_big
    label: 小→大
    type: number
  - name: big_core_pct
    label: 大核组占比（超大/大/中核）
    type: percentage
    format: percentage
  - name: unknown_core_ns
    label: 未知核类型运行
    type: duration
    unit: ns
    hidden: true
  - name: unique_cpus
    label: 使用核心数
    type: number
process_scope:
  role: target
  binding: effective_target_processes
sql_fragments:
- fragments/effective_target_processes.sql
- fragments/system_sched_spans.sql
save_as: migration_data
```
## Output and evidence contract

```yaml
format: structured
```
