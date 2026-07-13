GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/device_state_timeline.skill.yaml
Source SHA-256: 706331c8ba61ce76147693d6cb6cdf6758bdfc7ecab0b035ab635b86002efd08
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# 设备状态时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: device_state_timeline
version: '1.0'
type: composite
category: system_context
tier: A
```

## Metadata

```yaml
display_name: 设备状态时间线
description: 追踪设备状态随时间的变化（CPU 频率、GPU 频率、温度、内存压力）
icon: timeline
tags:
- device
- state
- timeline
- thermal
- cpu_freq
- memory
- trend
- atomic
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
```

## Ordered execution

### CPU 频率变化

- ID: `cpu_freq_transitions`
- Type: `atomic`
- SQL: [`../sql/device_state_timeline/cpu_freq_transitions.sql`](../sql/device_state_timeline/cpu_freq_transitions.sql)

```yaml
id: cpu_freq_transitions
type: atomic
display:
  level: detail
  layer: list
  title: CPU 频率变化时间线
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: cpu
    label: CPU 核心
    type: number
  - name: freq_mhz
    label: 频率(MHz)
    type: number
    format: compact
  - name: prev_freq_mhz
    label: 前一频率(MHz)
    type: number
    format: compact
  - name: delta_mhz
    label: 变化(MHz)
    type: number
    format: compact
  - name: transition_type
    label: 变化类型
    type: string
save_as: cpu_freq_transitions
optional: true
```
### 温度变化

- ID: `thermal_events`
- Type: `atomic`
- SQL: [`../sql/device_state_timeline/thermal_events.sql`](../sql/device_state_timeline/thermal_events.sql)

```yaml
id: thermal_events
type: atomic
display:
  level: detail
  layer: list
  title: 温度变化时间线
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: sensor_name
    label: 传感器
    type: string
  - name: temp_c
    label: 温度(C)
    type: number
    format: compact
  - name: delta_c
    label: 变化(C)
    type: number
    format: compact
  - name: severity
    label: 状态
    type: string
save_as: thermal_events
optional: true
```
### 内存压力变化

- ID: `memory_pressure_events`
- Type: `atomic`
- SQL: [`../sql/device_state_timeline/memory_pressure_events.sql`](../sql/device_state_timeline/memory_pressure_events.sql)

```yaml
id: memory_pressure_events
type: atomic
display:
  level: detail
  layer: list
  title: 内存压力变化时间线
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: counter_name
    label: 指标
    type: string
  - name: value
    label: 值
    type: number
    format: compact
  - name: prev_value
    label: 前一值
    type: number
    format: compact
  - name: delta
    label: 变化
    type: number
    format: compact
save_as: memory_pressure_events
optional: true
```
### GPU 频率变化

- ID: `gpu_freq_transitions`
- Type: `atomic`
- SQL: [`../sql/device_state_timeline/gpu_freq_transitions.sql`](../sql/device_state_timeline/gpu_freq_transitions.sql)

```yaml
id: gpu_freq_transitions
type: atomic
display:
  level: detail
  layer: list
  title: GPU 频率变化时间线
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: counter_name
    label: 指标
    type: string
  - name: freq_mhz
    label: 频率(MHz)
    type: number
    format: compact
  - name: prev_freq_mhz
    label: 前一频率(MHz)
    type: number
    format: compact
  - name: delta_mhz
    label: 变化(MHz)
    type: number
    format: compact
  - name: transition_type
    label: 变化类型
    type: string
save_as: gpu_freq_transitions
optional: true
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- cpu_freq_transitions
- thermal_events
```
