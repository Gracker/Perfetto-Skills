GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/binder_detail.skill.yaml
Source SHA-256: b21af48bb190aa382256c422c77267cce8f041f42257cbbd3a6f669e691f5bf9
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Binder 详情分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_detail
version: '2.0'
type: composite
category: kernel
tier: S
```

## Metadata

```yaml
display_name: Binder 详情分析
description: 深入分析单个 Binder 事务
icon: link_off
tags:
- binder
- detail
- composite
```

## Prerequisites

```yaml
required_tables:
- slice
```

## Inputs

```yaml
- name: binder_ts
  type: timestamp
  required: true
  description: Binder 开始时间戳(ns)
- name: binder_end_ts
  type: timestamp
  required: true
  description: Binder 结束时间戳(ns)
- name: dur_ms
  type: number
  required: true
  description: Binder 耗时(ms)
- name: server_process
  type: string
  required: true
  description: 服务进程
- name: aidl_name
  type: string
  required: false
  description: AIDL 方法名
- name: process_name
  type: string
  required: true
  description: 客户端进程名
- name: perfetto_start
  type: timestamp
  required: false
  description: Perfetto 跳转开始时间
- name: perfetto_end
  type: timestamp
  required: false
  description: Perfetto 跳转结束时间
```

## Identity requirements

```yaml
policy: required
scope: process
aliases:
- process_name
- package
rewriteTo: recommended_process_name_param
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
### Binder 基本信息

- ID: `binder_info`
- Type: `atomic`
- SQL: [`../sql/binder_detail/binder_info.sql`](../sql/binder_detail/binder_info.sql)

```yaml
id: binder_info
type: atomic
display:
  level: key
  layer: deep
  title: Binder 详情
  columns:
  - name: server_process
    label: 服务进程
    type: string
  - name: aidl_name
    label: AIDL 方法
    type: string
  - name: client_process
    label: 客户端进程
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: binder_ts
    label: 开始时间
    type: timestamp
    clickAction: navigate_range
    durationColumn: binder_end_ts
  - name: binder_end_ts
    label: 结束时间
    type: timestamp
    clickAction: navigate_timeline
    hidden: true
  - name: rating
    label: 评级
    type: string
save_as: binder_basic
```
### 大小核占比分析

- ID: `cpu_core_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_detail/cpu_core_analysis.sql`](../sql/binder_detail/cpu_core_analysis.sql)

```yaml
id: cpu_core_analysis
type: atomic
display:
  level: key
  layer: deep
  title: 大小核占比
  columns:
  - name: thread_type
    label: 线程
    type: string
  - name: big_core_ms
    label: 大核运行
    type: duration
    format: duration_ms
    unit: ms
  - name: little_core_ms
    label: 小核运行
    type: duration
    format: duration_ms
    unit: ms
  - name: total_running_ms
    label: 总 Running
    type: duration
    format: duration_ms
    unit: ms
  - name: running_pct
    label: Running 占比
    type: percentage
    format: percentage
save_as: cpu_core
```
### 四大象限分析

- ID: `quadrant_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_detail/quadrant_analysis.sql`](../sql/binder_detail/quadrant_analysis.sql)

```yaml
id: quadrant_analysis
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 四大象限分析
  columns:
  - name: thread_type
    label: 线程
    type: string
  - name: q1_big_running_ms
    label: Q1 大核 Running
    type: duration
    format: duration_ms
    unit: ms
  - name: q2_little_running_ms
    label: Q2 小核 Running
    type: duration
    format: duration_ms
    unit: ms
  - name: q3_runnable_ms
    label: Q3 Runnable
    type: duration
    format: duration_ms
    unit: ms
  - name: q4_sleeping_ms
    label: Q4 Sleeping
    type: duration
    format: duration_ms
    unit: ms
  - name: total_ms
    label: 总时间
    type: duration
    format: duration_ms
    unit: ms
  - name: sleeping_pct
    label: Sleeping 占比
    type: percentage
    format: percentage
save_as: quadrant
```
### 阻塞原因分析

- ID: `blocking_analysis`
- Type: `atomic`
- SQL: [`../sql/binder_detail/blocking_analysis.sql`](../sql/binder_detail/blocking_analysis.sql)

```yaml
id: blocking_analysis
type: atomic
optional: true
display:
  level: key
  layer: deep
  title: 阻塞原因
  columns:
  - name: state
    label: 线程状态
    type: string
  - name: state_desc
    label: 状态说明
    type: string
  - name: blocked_function
    label: 阻塞函数
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: count
    label: 次数
    type: number
    format: compact
save_as: blocking
```
### Binder 诊断

- ID: `binder_diagnosis`
- Type: `diagnostic`

```yaml
id: binder_diagnosis
type: diagnostic
display:
  level: key
  layer: deep
  title: 问题诊断
inputs:
- binder_basic
- cpu_core
- quadrant
- blocking
rules:
- condition: quadrant.data[0]?.sleeping_pct > 90
  severity: info
  diagnosis: 主线程在等待 Binder 回复 (${quadrant.data[0].sleeping_pct}% Sleeping)
  confidence: high
  suggestions:
  - 服务端处理时间过长
  - 考虑使用异步 Binder
- condition: cpu_core.data[0]?.running_pct > 30
  severity: info
  diagnosis: Binder 期间主线程 Running 占比 ${cpu_core.data[0].running_pct}%
  confidence: medium
  suggestions:
  - 可能存在客户端序列化开销
  - 检查传输数据大小
- condition: quadrant.data[0]?.q3_runnable_ms > 5
  severity: warning
  diagnosis: 主线程 Runnable 等待 ${quadrant.data[0].q3_runnable_ms}ms
  confidence: medium
  suggestions:
  - CPU 资源争抢
  - 检查系统负载
```
## Output and evidence contract

```yaml
display:
  level: key
  format: summary
```
