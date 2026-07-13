GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/wakelock_tracking.skill.yaml
Source SHA-256: 0384f134ae9d3dff888d962e31723669769e7f31268205c764b027d8888a973c
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Wake Lock 追踪

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wakelock_tracking
version: '1.0'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Wake Lock 追踪
description: 追踪 Wake Lock 持有情况，检测电池功耗异常
icon: battery_alert
tags:
- wakelock
- battery
- power
- suspend
- atomic
```

## Prerequisites

```yaml
required_tables:
- slice
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

### Wake Lock 事件

- ID: `wakelock_events`
- Type: `atomic`
- SQL: [`../sql/wakelock_tracking/wakelock_events.sql`](../sql/wakelock_tracking/wakelock_events.sql)

```yaml
id: wakelock_events
type: atomic
display:
  level: summary
  layer: overview
  title: Wake Lock 事件概览
  columns:
  - name: wakelock_name
    label: Wake Lock 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总持有时间
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均持有时间
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最长持有时间
    type: duration
    format: duration_ms
  - name: rating
    label: 评级
    type: string
save_as: wakelock_events
```
### Suspend Blocker

- ID: `suspend_blockers`
- Type: `atomic`
- SQL: [`../sql/wakelock_tracking/suspend_blockers.sql`](../sql/wakelock_tracking/suspend_blockers.sql)

```yaml
id: suspend_blockers
type: atomic
display:
  level: detail
  layer: list
  title: 内核 Suspend Blocker
  columns:
  - name: blocker_name
    label: Blocker 名称
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总阻止时间
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均阻止时间
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最长阻止时间
    type: duration
    format: duration_ms
save_as: suspend_blockers
```
### Wake Lock 持有时间排行

- ID: `wakelock_duration`
- Type: `atomic`
- SQL: [`../sql/wakelock_tracking/wakelock_duration.sql`](../sql/wakelock_tracking/wakelock_duration.sql)

```yaml
id: wakelock_duration
type: atomic
display:
  level: detail
  layer: list
  title: Wake Lock 累计持有时间排行
  columns:
  - name: wakelock_name
    label: Wake Lock 名称
    type: string
  - name: total_held_ms
    label: 累计持有时间
    type: duration
    format: duration_ms
  - name: total_held_pct
    label: 占比
    type: percentage
    format: percentage
  - name: acquire_count
    label: 获取次数
    type: number
    format: compact
  - name: avg_held_ms
    label: 平均持有
    type: duration
    format: duration_ms
save_as: wakelock_duration
```
### Wake Lock 时间线

- ID: `wakelock_timeline`
- Type: `atomic`
- SQL: [`../sql/wakelock_tracking/wakelock_timeline.sql`](../sql/wakelock_tracking/wakelock_timeline.sql)

```yaml
id: wakelock_timeline
type: atomic
display:
  level: detail
  layer: deep
  title: Wake Lock 时间线事件
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: wakelock_name
    label: Wake Lock 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: dur_ms
    label: 持有时间
    type: duration
    format: duration_ms
  - name: dur_ns
    label: 持有时间(ns)
    type: duration
    unit: ns
    hidden: true
  - name: status
    label: 状态
    type: string
save_as: wakelock_timeline
```
## Output and evidence contract

```yaml
format: structured
```
