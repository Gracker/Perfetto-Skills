GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/cpu_anomalous_threads_in_range.skill.yaml
Source SHA-256: ebd323de6763d2610995f371f900c448a892c16151ffa0bec43f440e1c702042
Source commit: bff733ed648b8d4bddf352f235599cf6c069e0a5
# 窗口异常线程识别

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: cpu_anomalous_threads_in_range
version: '1.0'
type: atomic
category: cpu
tier: A
```

## Metadata

```yaml
display_name: 窗口异常线程识别
description: 在指定窗口内按阈值标记持续占用、疑似空转、内核守护重载与唤醒风暴线程；标记即观测，不代表根因
icon: troubleshoot
tags:
- cpu
- sched
- anomaly
- thread
- range
- evidence
```

## Triggers

```yaml
keywords:
  zh:
  - 异常线程
  - 线程空转
  - 持续占用
  - 唤醒风暴
  en:
  - anomalous threads
  - spinning thread
  - sustained runner
  - wakeup storm
patterns:
- .*(异常|空转|占满|唤醒风暴).*线程.*
- .*(anomalous|spinning|runaway).*thread.*
```

## Prerequisites

```yaml
required_tables:
- sched_slice
- thread
modules:
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
- name: sustained_pct
  type: number
  required: false
  default: 80
  description: 持续占用阈值：线程运行时长占窗口时长的百分比
- name: spin_avg_slice_us
  type: number
  required: false
  default: 200
  description: 疑似空转阈值：平均调度片时长上限(us)
- name: spin_switches_per_s
  type: number
  required: false
  default: 2000
  description: 疑似空转阈值：每秒调度片数下限
- name: waker_per_s
  type: number
  required: false
  default: 500
  description: 唤醒风暴阈值：每秒发出唤醒次数下限
- name: kernel_daemon_share_pct
  type: number
  required: false
  default: 10
  description: 内核守护重载阈值：占窗口内全部运行时长的百分比
- name: top_n
  type: number
  required: false
  default: 30
  description: 最多返回的被标记线程数
```

## Ordered execution

### 窗口异常线程

- ID: `anomalous_threads`
- Type: `atomic`
- SQL: [`../sql/cpu_anomalous_threads_in_range/anomalous_threads.sql`](../sql/cpu_anomalous_threads_in_range/anomalous_threads.sql)

```yaml
id: anomalous_threads
type: atomic
process_scope:
  role: global_context
sql_fragments:
- fragments/system_sched_spans.sql
- fragments/actor_class_labels.sql
display:
  level: summary
  layer: list
  title: 窗口异常线程（阈值标记，非根因）
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
  - name: upid
    label: upid
    type: number
    hidden: true
  - name: utid
    label: utid
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
  - name: running_ns
    label: 运行时长
    type: duration
    unit: ns
  - name: running_pct_of_window
    label: 占窗口时长
    type: percentage
  - name: sched_slice_count
    label: 调度片数
    type: number
  - name: avg_slice_us
    label: 平均片长(us)
    type: number
  - name: switches_per_s
    label: 每秒调度片
    type: number
  - name: wakeups_sent_per_s
    label: 每秒发出唤醒
    type: number
  - name: waker_evidence
    label: 唤醒证据
    type: string
  - name: sustained_runner
    label: 持续占用
    type: boolean
  - name: spin_like
    label: 疑似空转
    type: boolean
  - name: kernel_daemon_heavy
    label: 内核守护重载
    type: boolean
  - name: waker_storm
    label: 唤醒风暴
    type: boolean
  - name: signal_count
    label: 命中信号数
    type: number
  - name: share_of_running_pct
    label: 占窗口运行时长
    type: percentage
  - name: thresholds
    label: 阈值
    type: string
  - name: status
    label: 状态
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有调度数据可供判定；确认 trace 含 ftrace sched/sched_switch 且窗口落在数据范围内。
save_as: anomalous_threads
```
## Output and evidence contract

```yaml
format: structured
```
