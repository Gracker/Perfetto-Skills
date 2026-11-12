GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/battery_doze_state_timeline.skill.yaml
Source SHA-256: 38c6fc6d472d705aaa1f872ee022272227ec52cff40e8269d1c1f0f44b2cc021
# Doze 休眠状态时间线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: battery_doze_state_timeline
version: '1.1'
type: atomic
category: power
tier: B
```

## Metadata

```yaml
display_name: Doze 休眠状态时间线
description: Deep/Light Doze 状态机区间（含状态）与全 trace 状态序列汇总
icon: bedtime
tags:
- doze
- idle
- battery
- power
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - Doze
  - 深度休眠
  - 待机
  - 灭屏耗电
  - 设备空闲
  en:
  - doze
  - device idle
  - deep idle
  - light idle
  - standby
```

## Prerequisites

```yaml
modules:
- android.battery.doze
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### Doze 状态机汇总

- ID: `doze_state_summary`
- Type: `atomic`
- SQL: [`../sql/battery_doze_state_timeline/doze_state_summary.sql`](../sql/battery_doze_state_timeline/doze_state_summary.sql)

```yaml
id: doze_state_summary
type: atomic
display:
  level: summary
  layer: overview
  title: Doze 状态机汇总
  title_i18n:
    en: Doze State Machine Summary
  row_semantics: per_entity
  columns:
  - name: state_machine
    label: 状态机
    label_i18n:
      en: State Machine
    type: string
  - name: trace_intervals
    label: 全 trace 区间数
    type: number
    format: compact
  - name: window_intervals
    label: 窗口内区间数
    type: number
    format: compact
    semantics: Intervals overlapping the requested start_ts/end_ts window (all of them when no window is given).
  - name: outside_window_intervals
    label: 窗口外区间数
    type: number
    format: compact
    semantics: Intervals entirely outside the requested window; nonzero means Doze transitions happened that the windowed
      interval rows below do not show.
  - name: idle_entries
    label: 进入 idle 次数
    type: number
    format: compact
  - name: first_idle_ts
    label: 首次进入 idle
    type: timestamp
    clickAction: navigate_timeline
  - name: idle_total_s
    label: idle 总时长(s)
    type: number
  - name: min_dwell_ms
    label: 最短状态驻留(ms)
    type: number
    semantics: Shortest observed nonfinal state dwell. A sub-second value shows a rapid transition; the first interval may
      be clipped by trace start. External forcing requires separate command or log evidence.
  - name: state_sequence
    label: 状态序列
    label_i18n:
      en: State Sequence
    type: string
    semantics: Decoded states in time order over the whole trace (first 24 intervals), joined by '>'.
  - name: last_state
    label: trace 末状态
    label_i18n:
      en: Last State
    type: string
save_as: doze_state_summary
```
### Deep Doze 状态区间

- ID: `deep_idle_intervals`
- Type: `atomic`
- SQL: [`../sql/battery_doze_state_timeline/deep_idle_intervals.sql`](../sql/battery_doze_state_timeline/deep_idle_intervals.sql)

```yaml
id: deep_idle_intervals
type: atomic
display:
  level: detail
  layer: list
  title: Deep Doze 状态区间
  title_i18n:
    en: Deep Doze State Intervals
  columns:
  - name: ts
    label: 起始
    type: timestamp
  - name: dur_sec
    label: 时长(秒)
    type: duration
    format: compact
  - name: deep_idle_state
    label: Deep Doze 状态
    label_i18n:
      en: Deep Doze State
    type: string
```
### Light Doze 状态区间

- ID: `light_idle_intervals`
- Type: `atomic`
- SQL: [`../sql/battery_doze_state_timeline/light_idle_intervals.sql`](../sql/battery_doze_state_timeline/light_idle_intervals.sql)

```yaml
id: light_idle_intervals
type: atomic
display:
  level: detail
  layer: list
  title: Light Doze 状态区间
  title_i18n:
    en: Light Doze State Intervals
  columns:
  - name: ts
    label: 起始
    type: timestamp
  - name: dur_sec
    label: 时长(秒)
    type: duration
    format: compact
  - name: light_idle_state
    label: Light Doze 状态
    label_i18n:
      en: Light Doze State
    type: string
```
