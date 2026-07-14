GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vrr_detection.skill.yaml
Source SHA-256: dbd96fdb066f3be0defa9135a69e115de91d28e52f9f9585a9fad0f12fd2cd06
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# VRR/LTPO 检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: vrr_detection
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: VRR/LTPO 检测
description: 检测可变刷新率 (VRR/LTPO/AdaptiveSync) 模式
icon: sync
tags:
- vrr
- ltpo
- refresh_rate
- adaptive
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - VRR
  - LTPO
  - 可变刷新率
  - 刷新率
  - AdaptiveSync
  - VSYNC
  en:
  - vrr
  - ltpo
  - variable refresh rate
  - adaptive sync
  - vsync
patterns:
- .*(VRR|LTPO|可变刷新率|刷新率).*
- .*(variable refresh|adaptive sync|vrr|ltpo).*
```

## Prerequisites

```yaml
required_tables:
- counter
- counter_track
modules:
- counters.intervals
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

### VSync 间隔分布

- ID: `vsync_interval_distribution`
- Type: `atomic`
- SQL: [`../sql/vrr_detection/vsync_interval_distribution.sql`](../sql/vrr_detection/vsync_interval_distribution.sql)

```yaml
id: vsync_interval_distribution
type: atomic
display:
  level: detail
  title: 刷新率分布
  columns:
  - name: refresh_rate_bucket
    label: 刷新率
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
  - name: total_duration_sec
    label: 时长(秒)
    type: number
  - name: avg_interval_ms
    label: 平均间隔
    type: duration
    format: duration_ms
    unit: ms
save_as: refresh_rate_distribution
```
### VRR 模式检测

- ID: `vrr_mode_detection`
- Type: `atomic`
- SQL: [`../sql/vrr_detection/vrr_mode_detection.sql`](../sql/vrr_detection/vrr_mode_detection.sql)

```yaml
id: vrr_mode_detection
type: atomic
display:
  level: summary
  title: VRR/LTPO 状态
  columns:
  - name: vrr_mode
    label: VRR模式
    type: string
  - name: active_refresh_rates
    label: 活跃刷新率数
    type: number
  - name: dominant_rate_pct
    label: 主导率占比
    type: percentage
    format: percentage
  - name: mode_description
    label: 描述
    type: string
  - name: sample_count
    label: 样本数
    type: number
    format: compact
save_as: vrr_status
```
### 刷新率切换事件

- ID: `refresh_rate_switches`
- Type: `atomic`
- SQL: [`../sql/vrr_detection/refresh_rate_switches.sql`](../sql/vrr_detection/refresh_rate_switches.sql)

```yaml
id: refresh_rate_switches
type: atomic
display:
  level: detail
  title: 刷新率切换
  columns:
  - name: transition
    label: 切换
    type: string
  - name: switch_count
    label: 切换次数
    type: number
    format: compact
save_as: rate_switches
optional: true
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: vrr_status
  description: VRR/LTPO 模式检测结果
- name: refresh_rate_distribution
  description: 刷新率分布统计
- name: rate_switches
  description: 刷新率切换事件
```
