GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/binder_storm_detection.skill.yaml
Source SHA-256: 85ad602601d09ed445ea984992373707cec45dc7255c375b7e7af6b610abe463
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Binder 风暴检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: binder_storm_detection
version: '1.0'
type: atomic
category: binder
tier: A
```

## Metadata

```yaml
display_name: Binder 风暴检测
description: 检测 Binder 事务风暴：短时间内过多 IPC 调用导致延迟或 ANR
icon: warning
tags:
- binder
- storm
- ipc
- burst
- saturation
- atomic
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- android.binder
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: threshold
  type: number
  required: false
  default: 50
  description: 100ms 窗口内 Binder 调用次数告警阈值
```

## Ordered execution

### Binder 调用密度

- ID: `binder_density`
- Type: `atomic`
- SQL: [`../sql/binder_storm_detection/binder_density.sql`](../sql/binder_storm_detection/binder_density.sql)

```yaml
id: binder_density
type: atomic
display:
  level: summary
  layer: overview
  title: Binder 调用密度（100ms 窗口）
  columns:
  - name: window_ts
    label: 窗口开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: txn_count
    label: 事务数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: status
    label: 状态
    type: string
save_as: binder_density
```
### 突发检测

- ID: `burst_detection`
- Type: `atomic`
- SQL: [`../sql/binder_storm_detection/burst_detection.sql`](../sql/binder_storm_detection/burst_detection.sql)

```yaml
id: burst_detection
type: atomic
display:
  level: detail
  layer: list
  title: Binder 突发事件
  columns:
  - name: burst_ts
    label: 突发开始
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: txn_count
    label: 事务数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: top_server
    label: 最多调用的服务
    type: string
  - name: top_server_count
    label: 服务调用次数
    type: number
  - name: severity
    label: 严重程度
    type: string
save_as: burst_detection
```
### 回调循环检测

- ID: `callback_loops`
- Type: `atomic`
- SQL: [`../sql/binder_storm_detection/callback_loops.sql`](../sql/binder_storm_detection/callback_loops.sql)

```yaml
id: callback_loops
type: atomic
display:
  level: detail
  layer: list
  title: Binder 回调循环（A→B→A）
  columns:
  - name: process_a
    label: 进程 A
    type: string
  - name: process_b
    label: 进程 B
    type: string
  - name: a_to_b_count
    label: A→B 次数
    type: number
    format: compact
  - name: b_to_a_count
    label: B→A 次数
    type: number
    format: compact
  - name: total_loop_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: loop_ratio
    label: 回调比
    type: number
save_as: callback_loops
```
### 缓冲区压力

- ID: `buffer_pressure`
- Type: `atomic`
- SQL: [`../sql/binder_storm_detection/buffer_pressure.sql`](../sql/binder_storm_detection/buffer_pressure.sql)

```yaml
id: buffer_pressure
type: atomic
display:
  level: detail
  layer: list
  title: Binder 缓冲区压力估算
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: total_txns
    label: 总事务数
    type: number
    format: compact
  - name: sync_txns
    label: 同步事务
    type: number
    format: compact
  - name: async_txns
    label: 异步事务
    type: number
    format: compact
  - name: total_client_ms
    label: 总客户端耗时
    type: duration
    format: duration_ms
  - name: concurrent_peak
    label: 并发峰值
    type: number
  - name: pressure_rating
    label: 压力评级
    type: string
save_as: buffer_pressure
```
## Output and evidence contract

```yaml
format: structured
```
