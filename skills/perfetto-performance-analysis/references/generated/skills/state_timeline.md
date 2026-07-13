GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/state_timeline.skill.yaml
Source SHA-256: e3ba12b4a53d3c90d152f942c7f910e4108218ef5da2c56c0e19561009686fc2
Source commit: 68b113e0355716255af357e8396cd71c71e11d97
# 连续状态时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: state_timeline
version: '1.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: 连续状态时间线
description: 从 Trace 起始到结束，按泳道展示设备/用户/应用/系统的连续状态
icon: view_timeline
tags:
- state
- timeline
- continuous
- swim_lane
- scene
```

## Triggers

```yaml
keywords:
  zh:
  - 状态时间线
  - 连续状态
  - 泳道
  - 设备状态
  - 用户状态
  en:
  - state timeline
  - continuous state
  - swim lane
  - device state
```

## Prerequisites

```yaml
modules:
- android.screen_state
- android.input
- android.battery_stats
```

## Inputs

```yaml
- name: trace_id
  type: string
  required: true
```

## Ordered execution

### 时间线范围与可用表

- ID: `timeline_bounds`
- Type: `atomic`
- SQL: [`../sql/state_timeline/timeline_bounds.sql`](../sql/state_timeline/timeline_bounds.sql)

```yaml
id: timeline_bounds
type: atomic
display:
  level: hidden
save_as: timeline_bounds
```
### 设备状态泳道

- ID: `device_state_lane`
- Type: `atomic`
- SQL: [`../sql/state_timeline/device_state_lane.sql`](../sql/state_timeline/device_state_lane.sql)

```yaml
id: device_state_lane
type: atomic
optional: true
condition: timeline_bounds.data[0]?.has_screen_state === 1
display:
  level: detail
  layer: list
  title: 设备状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 状态
    type: string
  - name: state_label
    label: 状态描述
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 设备状态泳道（降级）

- ID: `device_state_lane_fallback`
- Type: `atomic`
- SQL: [`../sql/state_timeline/device_state_lane_fallback.sql`](../sql/state_timeline/device_state_lane_fallback.sql)

```yaml
id: device_state_lane_fallback
type: atomic
condition: timeline_bounds.data[0]?.has_screen_state !== 1
display:
  level: detail
  layer: list
  title: 设备状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 状态
    type: string
  - name: state_label
    label: 状态描述
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 用户输入状态泳道（帧级）

- ID: `input_state_lane_frames`
- Type: `atomic`
- SQL: [`../sql/state_timeline/input_state_lane_frames.sql`](../sql/state_timeline/input_state_lane_frames.sql)

```yaml
id: input_state_lane_frames
type: atomic
optional: true
condition: timeline_bounds.data[0]?.has_frame_timeline === 1 && timeline_bounds.data[0]?.has_input_events === 1
display:
  level: detail
  layer: list
  title: 用户输入状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 状态
    type: string
  - name: state_label
    label: 状态描述
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 用户输入状态泳道（启发式）

- ID: `input_state_lane_fallback`
- Type: `atomic`
- SQL: [`../sql/state_timeline/input_state_lane_fallback.sql`](../sql/state_timeline/input_state_lane_fallback.sql)

```yaml
id: input_state_lane_fallback
type: atomic
optional: true
condition: timeline_bounds.data[0]?.has_frame_timeline !== 1 && timeline_bounds.data[0]?.has_input_events === 1
display:
  level: detail
  layer: list
  title: 用户输入状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 状态
    type: string
  - name: state_label
    label: 状态描述
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 应用状态泳道

- ID: `app_state_lane`
- Type: `atomic`
- SQL: [`../sql/state_timeline/app_state_lane.sql`](../sql/state_timeline/app_state_lane.sql)

```yaml
id: app_state_lane
type: atomic
optional: true
condition: timeline_bounds.data[0]?.has_battery_top === 1
display:
  level: detail
  layer: list
  title: 应用状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 应用
    type: string
  - name: state_label
    label: 应用名称
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 应用状态泳道（降级）

- ID: `app_state_lane_fallback`
- Type: `atomic`
- SQL: [`../sql/state_timeline/app_state_lane_fallback.sql`](../sql/state_timeline/app_state_lane_fallback.sql)

```yaml
id: app_state_lane_fallback
type: atomic
condition: timeline_bounds.data[0]?.has_battery_top !== 1
display:
  level: detail
  layer: list
  title: 应用状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 应用
    type: string
  - name: state_label
    label: 应用名称
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
```
### 系统状态泳道

- ID: `system_state_lane`
- Type: `atomic`
- SQL: [`../sql/state_timeline/system_state_lane.sql`](../sql/state_timeline/system_state_lane.sql)

```yaml
id: system_state_lane
type: atomic
display:
  level: detail
  layer: list
  title: 系统状态时间线
  columns:
  - name: lane
    label: 泳道
    type: string
    hidden: true
  - name: state
    label: 状态
    type: string
  - name: state_label
    label: 状态描述
    type: string
  - name: start_ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
  - name: end_ts
    label: 结束
    type: timestamp
    unit: ns
    hidden: true
  - name: dur_ns
    label: 时长(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 时长(ms)
    type: number
  - name: source_status
    label: 数据源
    type: string
    hidden: true
  - name: confidence
    label: 置信度
    type: string
    hidden: true
```
### 泳道统计汇总

- ID: `lane_summary`
- Type: `atomic`
- SQL: [`../sql/state_timeline/lane_summary.sql`](../sql/state_timeline/lane_summary.sql)

```yaml
id: lane_summary
type: atomic
display:
  level: summary
  layer: overview
  title: 状态时间线概览
  columns:
  - name: lane
    label: 泳道
    type: string
  - name: segment_count
    label: 段数
    type: number
  - name: total_dur_sec
    label: 总时长(秒)
    type: number
  - name: dominant_state
    label: 主要状态
    type: string
  - name: source_status
    label: 数据源
    type: string
```
## Output and evidence contract

```yaml
format: layered
default_expanded:
- device_state_lane
- device_state_lane_fallback
- input_state_lane_frames
- input_state_lane_fallback
- app_state_lane
- app_state_lane_fallback
- system_state_lane
```
