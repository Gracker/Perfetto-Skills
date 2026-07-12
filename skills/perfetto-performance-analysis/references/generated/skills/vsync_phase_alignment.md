GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/vsync_phase_alignment.skill.yaml
Source SHA-256: f1629db2e1ddf7711964f2b32f51d60012885ff3c966af974128cb5ed150e700
Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26
# VSync 相位对齐分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: vsync_phase_alignment
version: '2.0'
type: atomic
category: input_response
tier: A
```

## Metadata

```yaml
display_name: VSync 相位对齐分析
description: 基于 android_input_events 分析输入事件与 VSync 信号的相位关系
icon: sync
tags:
- vsync
- phase
- alignment
- input
- latency
- touch_tracking
- atomic
pipeline_aware: true
pipeline_aware_note: '输入相位对齐在不同 pipeline 不同：标准 vsync-app；Game Swappy 自管 frame pacing；

  Flutter Engine vsync 经 JNI 桥接。未来按 pipeline_id 切换 input→vsync 路径解析。

  '
```

## Prerequisites

```yaml
modules:
- android.input
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
```

## Ordered execution

### VSync 时间线

- ID: `vsync_timeline`
- Type: `atomic`
- SQL: [`../sql/vsync_phase_alignment/vsync_timeline.sql`](../sql/vsync_phase_alignment/vsync_timeline.sql)

```yaml
id: vsync_timeline
type: atomic
display:
  level: summary
  layer: overview
  title: VSync 配置
  columns:
  - name: vsync_count
    label: VSync 数量
    type: number
  - name: period_ms
    label: VSync 周期(ms)
    type: number
  - name: refresh_hz
    label: 刷新率(Hz)
    type: number
```
### 相位偏移分析

- ID: `phase_analysis`
- Type: `atomic`
- SQL: [`../sql/vsync_phase_alignment/phase_analysis.sql`](../sql/vsync_phase_alignment/phase_analysis.sql)

```yaml
id: phase_analysis
type: atomic
display:
  level: detail
  layer: list
  title: Input-VSync 相位偏移
  columns:
  - name: input_ts
    label: 输入时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: nearest_vsync_ts
    label: 最近VSync
    type: timestamp
    unit: ns
  - name: phase_offset_ms
    label: 相位偏移(ms)
    type: number
  - name: phase_ratio_pct
    label: 相位比(%)
    type: percentage
  - name: wait_ms
    label: VSync等待(ms)
    type: duration
    format: duration_ms
```
### 相位分布统计

- ID: `phase_distribution`
- Type: `atomic`
- SQL: [`../sql/vsync_phase_alignment/phase_distribution.sql`](../sql/vsync_phase_alignment/phase_distribution.sql)

```yaml
id: phase_distribution
type: atomic
display:
  level: summary
  layer: overview
  title: 相位分布统计
  columns:
  - name: metric
    label: 指标
    type: string
  - name: value
    label: 值
    type: string
```
## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: VSync 相位对齐
columns:
- name: input_ts
  label: 输入时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: phase_offset_ms
  label: 相位偏移(ms)
  type: number
- name: phase_ratio
  label: 相位比(%)
  type: percentage
- name: wait_until_next_vsync_ms
  label: 等待下个VSync(ms)
  type: duration
  format: duration_ms
```
