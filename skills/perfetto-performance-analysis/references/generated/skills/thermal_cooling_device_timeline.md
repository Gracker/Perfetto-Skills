GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/thermal_cooling_device_timeline.skill.yaml
Source SHA-256: 212c1203887256c5706a1e12c54ae6d163c0bb8647edd88afb0f73cc624cf16f
Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799
# 散热设备状态时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: thermal_cooling_device_timeline
version: '1.0'
type: atomic
category: thermal
tier: B
```

## Metadata

```yaml
display_name: 散热设备状态时间线
description: 读取内核 cooling device 目标状态的区段与转换；缺失不等于未发生热控
icon: ac_unit
tags:
- thermal
- cooling
- cdev
- kernel
- evidence
```

## Triggers

```yaml
keywords:
  zh:
  - 散热设备
  - 冷却设备
  - cooling device
  - 热控状态
  en:
  - cooling device
  - cdev
  - thermal cooling state
patterns:
- .*(散热|冷却).*设备.*
- .*cooling.*device.*
```

## Prerequisites

```yaml
required_tables:
- counter_track
- counter
modules:
- linux.cpu.frequency
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)；缺省使用观测数据起点
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)；缺省使用 trace 数据终点
- name: max_transitions
  type: number
  required: false
  default: 200
  description: 返回的状态转换行数上限
```

## Ordered execution

### 散热设备数据检测

- ID: `cooling_data_check`
- Type: `atomic`
- SQL: [`../sql/thermal_cooling_device_timeline/cooling_data_check.sql`](../sql/thermal_cooling_device_timeline/cooling_data_check.sql)

```yaml
id: cooling_data_check
type: atomic
process_scope:
  role: global_context
display: false
save_as: cooling_data_check
```
### 散热设备概览

- ID: `cooling_summary`
- Type: `atomic`
- SQL: [`../sql/thermal_cooling_device_timeline/cooling_summary.sql`](../sql/thermal_cooling_device_timeline/cooling_summary.sql)

```yaml
id: cooling_summary
type: atomic
condition: cooling_data_check.data?.[0]?.has_cdev_data === 1
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_cooling_spans.sql
display:
  level: summary
  layer: overview
  title: 散热设备状态概览
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
  - name: cdev_name
    label: 散热设备
    type: string
  - name: cdev_kind_hint
    label: 疑似作用域
    type: string
  - name: cdev_kind_basis
    label: 判定依据
    type: string
  - name: max_state
    label: 最高档位
    type: number
  - name: min_state
    label: 最低档位
    type: number
  - name: mean_state
    label: 时间加权均值
    type: number
  - name: transition_count
    label: 状态转换数
    type: number
  - name: active_ns
    label: 非零档位时长
    type: duration
    unit: ns
  - name: active_pct
    label: 非零档位占比
    type: percentage
  - name: first_ts
    label: 首个样本
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: last_ts
    label: 最后样本
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: covered_ns
    label: 覆盖时长
    type: duration
    unit: ns
  - name: cooling_evidence
    label: 散热证据
    type: string
  - name: cooling_source
    label: 数据来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
save_as: cooling_summary
```
### 散热设备状态转换

- ID: `cooling_transitions`
- Type: `atomic`
- SQL: [`../sql/thermal_cooling_device_timeline/cooling_transitions.sql`](../sql/thermal_cooling_device_timeline/cooling_transitions.sql)

```yaml
id: cooling_transitions
type: atomic
condition: cooling_data_check.data?.[0]?.has_cdev_data === 1
optional: true
process_scope:
  role: global_context
sql_fragments:
- fragments/thermal_cooling_spans.sql
display:
  level: detail
  layer: list
  title: 散热设备状态转换
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: cdev_name
    label: 散热设备
    type: string
  - name: cdev_kind_hint
    label: 疑似作用域
    type: string
  - name: prev_state
    label: 变更前
    type: number
  - name: state
    label: 变更后
    type: number
  - name: direction
    label: 方向
    type: string
  - name: dur_ns
    label: 保持时长
    type: duration
    unit: ns
  - name: cooling_source
    label: 数据来源
    type: string
  - name: evidence_scope
    label: 证据范围
    type: string
on_empty: 窗口内没有散热设备状态转换。
save_as: cooling_transitions
```
### 无散热设备数据

- ID: `cooling_unavailable`
- Type: `atomic`
- SQL: [`../sql/thermal_cooling_device_timeline/cooling_unavailable.sql`](../sql/thermal_cooling_device_timeline/cooling_unavailable.sql)

```yaml
id: cooling_unavailable
type: atomic
condition: cooling_data_check.data?.[0]?.has_cdev_data !== 1
process_scope:
  role: global_context
display:
  level: summary
  layer: overview
  title: 无内核散热设备数据
  columns:
  - name: cooling_evidence
    label: 散热证据
    type: string
  - name: required_ftrace_event
    label: 需要采集的 ftrace 事件
    type: string
  - name: message
    label: 说明
    type: string
save_as: cooling_unavailable
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- cooling_summary
```
