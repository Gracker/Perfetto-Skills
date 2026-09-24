GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/scene_device_state_changes.skill.yaml
Source SHA-256: 095556b596031e7b8be9188eb7fef73927a190792460e88d97c190453848ed5f
Source commit: 98eb78f5af52822edd880b120aa27e2f5f41c6df
# 场景设备状态变化

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scene_device_state_changes
version: '1.0'
type: composite
category: system_context
tier: B
```

## Metadata

```yaml
display_name: 场景设备状态变化
description: 查询屏幕、充电和已提交 DeviceState 的瞬时事件与派生持续状态；保留厂商状态原值，不凭状态编号猜测折叠姿态。
icon: devices
tags:
- scene
- device
- screen
- charging
- posture
- state
```

## Prerequisites

```yaml
modules:
- android.screen_state
- android.battery.charging_states
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: row_limit
  type: number
  required: false
  default: 4096
```

## Ordered execution

### 设备状态采集范围

- ID: `state_sources`
- Type: `atomic`
- SQL: [`../sql/scene_device_state_changes/state_sources.sql`](../sql/scene_device_state_changes/state_sources.sql)

```yaml
id: state_sources
type: atomic
display:
  level: detail
  layer: list
  title: 设备状态数据来源
sql_fragments:
- fragments/scene_device_state_facts.sql
save_as: state_sources
```
### 设备状态区间

- ID: `state_intervals`
- Type: `atomic`
- SQL: [`../sql/scene_device_state_changes/state_intervals.sql`](../sql/scene_device_state_changes/state_intervals.sql)

```yaml
id: state_intervals
type: atomic
display:
  level: detail
  layer: list
  title: 设备状态变化
  columns:
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
  - name: dur_ns
    label: 持续
    type: duration
    unit: ns
  - name: dimension
    label: 维度
    type: string
  - name: fact_kind
    label: 事实类型
    type: string
  - name: state_value
    label: 状态原值
    type: string
  - name: source_status
    label: 证据状态
    type: string
  - name: boundary_basis
    label: 边界依据
    type: string
sql_fragments:
- fragments/scene_device_state_facts.sql
save_as: state_intervals
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- state_sources
- state_intervals
```
