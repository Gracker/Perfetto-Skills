GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/task_migration_in_range.skill.yaml
Source SHA-256: 1b05bdb3c94d10130b9a0a89dc4e197560e6c66e235eca7924f7b6fe80d9df88
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
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
  description: 目标进程名（支持 GLOB 匹配）
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
    label: 大核占比
    type: percentage
    format: percentage
  - name: unique_cpus
    label: 使用核心数
    type: number
save_as: migration_data
```
## Output and evidence contract

```yaml
format: structured
```
