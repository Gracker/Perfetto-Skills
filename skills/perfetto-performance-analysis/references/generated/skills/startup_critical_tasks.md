GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/startup_critical_tasks.skill.yaml
Source SHA-256: 425297e5c75ebc5b5eca49affc78e4dc1ab558e52e841f51aa1a4d8d1ec83aac
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 启动关键任务发现

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
- sched
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
- name: q4a_io_blocked_ms
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
- name: migrations
  label: 核迁移次数
  type: number
- name: cross_cluster_migrations
  label: 跨 cluster 迁移
  type: number
```
