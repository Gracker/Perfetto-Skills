GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_critical_tasks.skill.yaml
Source SHA-256: 7d1fb6e3724c17a9610aa5aa28d054f13a96c7a2ee6e955ac720bfcaee25de9f
Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5
# 启动关键任务发现

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: startup_critical_tasks
version: '1.0'
type: atomic
category: app_lifecycle
tier: A
```

## Metadata

```yaml
display_name: 启动关键任务发现
description: 自动识别启动区间内所有活跃线程，按 CPU 时间排序，提供每线程四象限 + 摆核分析
icon: groups
tags:
- startup
- critical_task
- multi_thread
- quadrant
- migration
- atomic
```

## Prerequisites

```yaml
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: package
  type: string
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: top_k
  type: number
  required: false
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
```

## Query

Run [`../sql/startup_critical_tasks/query.sql`](../sql/startup_critical_tasks/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: deep
title: 启动关键任务（全线程四象限）
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
- name: total_observed_threads
  label: total_observed_threads
  type: number
  hidden: true
- name: upid
  label: UPID
  type: number
- name: utid
  label: UTID
  type: number
- name: thread_name
  label: 线程
  type: string
- name: tid
  label: TID
  type: number
- name: role
  label: 角色
  type: string
- name: total_cpu_ms
  label: CPU 时间
  type: duration
  format: duration_ms
  unit: ms
- name: q1_big_running_ms
  label: Q1 大核运行
  type: duration
  format: duration_ms
  unit: ms
- name: q2_little_running_ms
  label: Q2 小核运行
  type: duration
  format: duration_ms
  unit: ms
- name: q3_runnable_ms
  label: Q3 等待调度
  type: duration
  format: duration_ms
  unit: ms
- name: unknown_running_ms
  label: 未知核类型运行(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: other_state_ms
  label: 其他观测状态(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: q4a_uninterruptible_ms
  label: Q4a 不可中断等待
  type: duration
  format: duration_ms
  unit: ms
- name: q4b_sleeping_ms
  label: Q4b 睡眠等待
  type: duration
  format: duration_ms
  unit: ms
- name: total_ms
  label: 总状态时间
  type: duration
  format: duration_ms
  unit: ms
- name: running_pct
  label: 运行占比
  type: percentage
  format: percentage
- name: big_core_pct
  label: 大核占比
  type: percentage
  format: percentage
- name: observed_cross_cluster_migrations
  label: 已确认跨Cluster迁移
  type: number
  hidden: true
- name: unknown_cluster_migrations
  label: Cluster关系未知迁移
  type: number
  hidden: true
- name: migration_evidence
  label: 迁移证据范围
  type: string
  hidden: true
- name: migrations
  label: 核迁移次数
  type: number
- name: cross_cluster_migrations
  label: 跨 cluster 迁移
  type: number
- name: priority_min
  label: 最小 kernel priority
  type: number
- name: priority_max
  label: 最大 kernel priority
  type: number
- name: priority_value_count
  label: 观测 priority 值数
  type: number
- name: preemption_count
  label: 窗口内 R+ 切出次数
  type: number
- name: runnable_preempted_ms
  label: R+ 等待(ms)
  type: duration
  format: duration_ms
  unit: ms
- name: scheduling_policy_evidence
  label: 调度策略证据
  type: string
- name: pid
  label: PID
  type: number
  hidden: true
- name: process_name
  label: 进程
  type: string
  hidden: true
- name: priority_evidence
  label: 优先级证据
  type: string
  hidden: true
```
