GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/process_thread_wait_sources_in_range.skill.yaml
Source SHA-256: a63b33f91c961cf74a88510339a24499fc5a04d98ba04563ebe10ddd9bfc76e1
Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5
# 线程等待来源归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: process_thread_wait_sources_in_range
version: '1.0'
type: composite
category: diagnostics
tier: B
```

## Metadata

```yaml
display_name: 线程等待来源归因
description: 按唤醒来源归因进程内线程的 S/I 态等待：网络收包候选、worker 交接、binder 回复、系统服务、定时器
icon: hourglass_empty
tags:
- wait
- wake_source
- waker
- network
- worker
- loading
- diagnostics
```

## Triggers

```yaml
keywords:
  zh:
  - 线程等待
  - 等待来源
  - 唤醒来源
  - 内容加载
  - 网络等待
  - worker
  - 交接
  - 加载慢
  en:
  - wait source
  - wake source
  - waker
  - thread wait
  - network wait
  - worker handoff
  - loading
patterns:
- .*等待来源.*
- .*唤醒来源.*
- .*wait source.*
- .*wake source.*
```

## Prerequisites

```yaml
required_tables:
- thread_state
- thread
- process
modules:
- android.network_packets
```

## Inputs

```yaml
- name: package
  type: string
  required: true
  description: 目标进程名/包名
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: upid
  type: number
  required: false
  description: 可选：精确 upid，用于在同名多进程时消歧
- name: pid
  type: number
  required: false
  description: 可选：精确 pid，用于在同名多进程时消歧
- name: top_k
  type: number
  required: false
  description: 汇总与明细的最大返回行数
```

## Identity requirements

```yaml
policy: verify_if_present
scope: process
aliases:
- package
- process_name
```

## Ordered execution

### 唤醒证据可用性

- ID: `wake_evidence_scope`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/wake_evidence_scope.sql`](../sql/process_thread_wait_sources_in_range/wake_evidence_scope.sql)

```yaml
id: wake_evidence_scope
type: atomic
display:
  level: summary
  layer: overview
  title: 唤醒来源证据范围
  columns:
  - name: status
    label: 唤醒证据
    type: string
  - name: evidence_class
    label: 证据类型
    type: string
  - name: waker_rows
    label: 带唤醒者的 R 行
    type: number
    format: compact
  - name: irq_wake_rows
    label: irq 上下文唤醒行
    type: number
    format: compact
  - name: sleep_rows
    label: 窗口内 S/I 等待行
    type: number
    format: compact
  - name: supported_claims
    label: 可支持结论
    type: string
  - name: unsupported_claims
    label: 不可直接证明
    type: string
synthesize:
  role: overview
  fields:
  - key: status
    label: 唤醒证据
  - key: sleep_rows
    label: S/I 等待行
  insights:
  - condition: status === 'unavailable'
    template: 该进程窗口内没有带唤醒者的 R 行，等待来源无法归因；需补录 sched/sched_waking
process_scope:
  role: target
  binding: native_upid
save_as: wake_evidence_scope
```
### 按角色的线程状态分布

- ID: `role_state_summary`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/role_state_summary.sql`](../sql/process_thread_wait_sources_in_range/role_state_summary.sql)

```yaml
id: role_state_summary
type: atomic
display:
  level: key
  layer: overview
  title: 线程角色状态分布（窗口内）
  columns:
  - name: thread_role
    label: 线程角色
    type: string
  - name: thread_count
    label: 线程数
    type: number
    format: compact
  - name: running_ms
    label: Running(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: runnable_ms
    label: Runnable(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: sleeping_ms
    label: S/I 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: uninterruptible_ms
    label: D/DK 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: state_rows
    label: 状态行数
    type: number
    format: compact
process_scope:
  role: target
  binding: native_upid
sql_fragments:
- fragments/thread_role.sql
save_as: role_state_summary
```
### 等待类别分布

- ID: `wait_class_summary`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/wait_class_summary.sql`](../sql/process_thread_wait_sources_in_range/wait_class_summary.sql)

```yaml
id: wait_class_summary
type: atomic
display:
  level: key
  layer: overview
  title: S/I 等待按唤醒来源归类（候选）
  columns:
  - name: thread_role
    label: 线程角色
    type: string
  - name: wait_class
    label: 等待类别（候选）
    type: string
  - name: wake_source
    label: 唤醒来源
    type: string
  - name: wait_count
    label: 等待次数
    type: number
    format: compact
  - name: thread_count
    label: 涉及线程数
    type: number
    format: compact
  - name: total_wait_ms
    label: 窗口内等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: max_wait_ms
    label: 最长单次等待(ms)
    type: duration
    format: duration_ms
    unit: ms
synthesize:
  role: overview
  fields:
  - key: wait_class
    label: 等待类别
  - key: total_wait_ms
    label: 等待时长
    format: '{{value}} ms'
  insights:
  - condition: wait_class === 'network_receive_candidate'
    template: '{{thread_role}} 线程有 {{total_wait_ms}} ms 的等待由 irq 上下文唤醒，是收包候选；需 rx 包相关或网络库埋点确认'
  - condition: wait_class === 'worker_handoff'
    template: '{{thread_role}} 线程有 {{total_wait_ms}} ms 的等待由同进程线程唤醒，属于线程间交接'
process_scope:
  role: target
  binding: native_upid
sql_fragments:
- fragments/thread_role.sql
- fragments/sleep_wake_source.sql
- fragments/sleep_wake_source_labels.sql
save_as: wait_class_summary
```
### 最长等待明细

- ID: `top_waits`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/top_waits.sql`](../sql/process_thread_wait_sources_in_range/top_waits.sql)

```yaml
id: top_waits
type: atomic
display:
  level: detail
  layer: list
  title: 最长 S/I 等待及其唤醒者
  columns:
  - name: wait_start_ts
    label: 等待开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 等待(ns)
    type: duration
    unit: ns
    hidden: true
  - name: wait_ms
    label: 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 等待线程
    type: string
  - name: tid
    label: TID
    type: number
  - name: thread_role
    label: 线程角色
    type: string
  - name: state
    label: 状态
    type: string
  - name: wait_class
    label: 等待类别（候选）
    type: string
  - name: wake_source
    label: 唤醒来源
    type: string
  - name: waker_thread_name
    label: 唤醒者线程
    type: string
  - name: waker_process_name
    label: 唤醒者进程
    type: string
  - name: waker_role
    label: 唤醒者角色
    type: string
  - name: irq_context
    label: irq 上下文
    type: number
  - name: process_name
    label: 进程
    type: string
    hidden: true
process_scope:
  role: target
  binding: native_upid
sql_fragments:
- fragments/thread_role.sql
- fragments/sleep_wake_source.sql
- fragments/sleep_wake_source_labels.sql
save_as: top_waits
```
### 检查网络包数据

- ID: `packet_check`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/packet_check.sql`](../sql/process_thread_wait_sources_in_range/packet_check.sql)

```yaml
id: packet_check
type: atomic
display: false
process_scope:
  role: global_context
save_as: packet_check
```
### 收包时间相关

- ID: `network_packet_correlation`
- Type: `atomic`
- SQL: [`../sql/process_thread_wait_sources_in_range/network_packet_correlation.sql`](../sql/process_thread_wait_sources_in_range/network_packet_correlation.sql)

```yaml
id: network_packet_correlation
type: atomic
display:
  level: detail
  layer: list
  title: 网络收包与等待唤醒的时间相关
  columns:
  - name: wait_start_ts
    label: 等待开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 等待(ns)
    type: duration
    unit: ns
    hidden: true
  - name: wait_ms
    label: 等待(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: thread_name
    label: 等待线程
    type: string
  - name: thread_role
    label: 线程角色
    type: string
  - name: wait_class
    label: 等待类别
    type: string
  - name: evidence_class
    label: 证据类型
    type: string
  - name: packet_ts
    label: rx 包时刻
    type: timestamp
    unit: ns
  - name: packet_gap_ms
    label: 包到唤醒间隔(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: packet_length
    label: 包字节数
    type: bytes
  - name: packet_iface
    label: 接口
    type: string
process_scope:
  role: target
  binding: native_upid
  limitations:
  - android_network_packets 只带 package_name，无法按 upid 精确绑定收包行
sql_fragments:
- fragments/thread_role.sql
- fragments/sleep_wake_source.sql
- fragments/sleep_wake_source_labels.sql
save_as: network_packet_correlation
condition: packet_check.data[0]?.status === 'available'
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- wake_evidence_scope
- role_state_summary
- wait_class_summary
- top_waits
```
