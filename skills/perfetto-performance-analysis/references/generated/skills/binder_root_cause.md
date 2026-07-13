GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/binder_root_cause.skill.yaml
Source SHA-256: 9fb3e26f37f2a7dead03e0b85dda71300e9c3c216b4676072b9ef31385ea33ec
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# Binder 根因归因

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_root_cause
version: '1.0'
type: composite
category: ipc
tier: B
```

## Metadata

```yaml
display_name: Binder 根因归因
description: 分析慢 Binder 事务的服务端/客户端阻塞原因（GC/锁/IO/内存回收）
icon: call_split
tags:
- binder
- root_cause
- breakdown
- diagnostics
```

## Prerequisites

```yaml
modules:
- android.binder_breakdown
- android.binder
```

## Inputs

```yaml
- name: process_name
  type: string
  required: true
  description: 目标进程名
- name: start_ts
  type: timestamp
  required: true
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 分析结束时间戳(ns)
- name: min_dur_ms
  type: number
  required: false
  description: 最小 Binder 事务时长阈值(ms)，默认 1ms
```

## Ordered execution

### 慢 Binder 事务阻塞归因

- ID: `slow_binder_breakdown`
- Type: `atomic`
- SQL: [`../sql/binder_root_cause/slow_binder_breakdown.sql`](../sql/binder_root_cause/slow_binder_breakdown.sql)

```yaml
id: slow_binder_breakdown
type: atomic
display:
  level: key
  layer: list
  title: 慢 Binder 事务阻塞原因明细
  columns:
  - name: interface
    label: 接口
    type: string
  - name: server_process
    label: 服务端进程
    type: string
  - name: client_dur_ms
    label: 客户端耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: server_dur_ms
    label: 服务端耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: reason
    label: 阻塞原因
    type: string
  - name: reason_type
    label: 原因类型
    type: string
  - name: reason_dur_ms
    label: 原因耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
  - name: reason_pct
    label: 原因占比(%)
    type: percentage
    format: percentage
save_as: slow_binder_breakdown
optional: true
```
### 阻塞原因汇总

- ID: `blame_summary`
- Type: `atomic`
- SQL: [`../sql/binder_root_cause/blame_summary.sql`](../sql/binder_root_cause/blame_summary.sql)

```yaml
id: blame_summary
type: atomic
display:
  level: key
  layer: overview
  title: Binder 阻塞原因汇总
  columns:
  - name: reason
    label: 阻塞原因
    type: string
  - name: reason_type
    label: 原因类型
    type: string
  - name: txn_count
    label: 事务数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时(ms)
    type: duration
    format: duration_ms
    unit: ms
synthesize:
  role: overview
  fields:
  - key: reason
    label: 原因
  - key: total_dur_ms
    label: 总耗时
    format: '{{value}} ms'
  - key: txn_count
    label: 事务数
  insights:
  - condition: reason_type === 'gc' && total_dur_ms > 5
    template: GC 导致 Binder 阻塞 {{total_dur_ms}}ms，影响 {{txn_count}} 个事务
  - condition: reason_type === 'lock_contention' && total_dur_ms > 5
    template: 锁竞争导致 Binder 阻塞 {{total_dur_ms}}ms，需检查同步代码
save_as: blame_summary
optional: true
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- blame_summary
- slow_binder_breakdown
```
