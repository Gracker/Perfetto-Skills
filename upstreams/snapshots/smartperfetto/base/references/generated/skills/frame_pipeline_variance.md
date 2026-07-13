GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/frame_pipeline_variance.skill.yaml
Source SHA-256: 950462b8e2b44ec13d3e9173fa31326ad38fd20335c64190a8a35c9111e9af9c
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 帧管线方差分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: frame_pipeline_variance
version: '1.0'
type: atomic
category: frame
tier: B
```

## Metadata

```yaml
display_name: 帧管线方差分析
description: 检测帧时长抖动与高方差区间
icon: show_chart
tags:
- frame
- jank
- variance
- frametimeline
pipeline_aware: true
pipeline_aware_note: '方差计算的 frame 来源不同：标准用 FrameTimeline；Game 用 producer thread submit interval；

  Camera 用 HAL processCaptureResult interval；Tunneled Video 用 HAL trace。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 帧抖动
  - 方差
  - 波动
  - 帧不稳定
  - 帧时间
  en:
  - frame variance
  - frame jitter
  - frame stability
patterns:
- .*(frame|jank).*(variance|jitter).*
- .*(帧|掉帧).*(抖动|方差|波动).*
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名(可选)
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns，可选)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns，可选)
- name: transition_threshold_ms
  type: number
  required: false
  default: 8
  description: 高抖动阈值(ms)
```

## Query

Run [`../sql/frame_pipeline_variance/query.sql`](../sql/frame_pipeline_variance/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: summary
layer: overview
title: 帧管线方差
columns:
- name: total_frames
  label: 总帧数
  type: number
- name: avg_frame_ms
  label: 平均帧耗时
  type: duration
  format: duration_ms
  unit: ms
- name: stddev_ms
  label: 标准差
  type: duration
  format: duration_ms
  unit: ms
- name: avg_delta_ms
  label: 帧间波动
  type: duration
  format: duration_ms
  unit: ms
- name: high_variance_transitions
  label: 高抖动转折
  type: number
- name: variance_level
  label: 抖动等级
  type: string
```
