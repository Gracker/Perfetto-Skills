GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/scroll_session_analysis.skill.yaml
Source SHA-256: fd8dbf2ef3390842217b4b5877ff5a8dd65c44f0edbaaa4d59ba036370f53517
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# 滑动会话分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scroll_session_analysis
version: '1.0'
type: composite
category: interaction
tier: S
```

## Metadata

```yaml
display_name: 滑动会话分析
description: 分析滑动操作的流畅度
icon: swipe
tags:
- scroll
- jank
- interaction
- composite
```

## Prerequisites

```yaml
required_tables:
- android_input_event
```

## Inputs

```yaml
- name: session_id
  type: number
  required: true
- name: start_ts
  type: timestamp
  required: true
- name: end_ts
  type: timestamp
  required: true
- name: duration_ms
  type: number
  required: false
- name: frame_count
  type: number
  required: false
- name: touch_start_ts
  type: timestamp
  required: false
- name: touch_end_ts
  type: timestamp
  required: false
- name: touch_duration_ms
  type: number
  required: false
- name: fling_start_ts
  type: timestamp
  required: false
- name: fling_end_ts
  type: timestamp
  required: false
- name: fling_duration_ms
  type: number
  required: false
- name: has_fling
  type: number
  required: false
```

## Context requirements

```yaml
- package
- vsync_period_ns
- refresh_rate_hz
```

## Ordered execution

### 完整区间统计

- ID: `full_session_stats`
- Type: `atomic`
- SQL: [`../sql/scroll_session_analysis/full_session_stats.sql`](../sql/scroll_session_analysis/full_session_stats.sql)

```yaml
id: full_session_stats
type: atomic
display:
  level: summary
  layer: session
  title: 区间 ${session_id} - 完整滑动统计
  columns:
  - name: session_id
    label: 区间
    type: number
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: janky_frames
    label: 掉帧数
    type: number
    format: compact
  - name: jank_rate
    label: 掉帧率
    type: percentage
    format: percentage
  - name: avg_frame_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frame_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: min_frame_ms
    label: 最小帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: estimated_fps
    label: 估算 FPS
    type: number
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
save_as: full_stats
```
### 按压滑动阶段统计

- ID: `touch_phase_stats`
- Type: `atomic`
- SQL: [`../sql/scroll_session_analysis/touch_phase_stats.sql`](../sql/scroll_session_analysis/touch_phase_stats.sql)

```yaml
id: touch_phase_stats
type: atomic
display:
  level: detail
  layer: session
  title: 区间 ${session_id} - 按压滑动阶段
  columns:
  - name: phase
    label: 阶段
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: janky_count
    label: 掉帧数
    type: number
    format: compact
  - name: jank_rate
    label: 掉帧率
    type: percentage
    format: percentage
  - name: avg_frame_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frame_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: fps
    label: FPS
    type: number
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
save_as: touch_stats
condition: touch_start_ts != null
```
### Fling 阶段统计

- ID: `fling_phase_stats`
- Type: `atomic`
- SQL: [`../sql/scroll_session_analysis/fling_phase_stats.sql`](../sql/scroll_session_analysis/fling_phase_stats.sql)

```yaml
id: fling_phase_stats
type: atomic
display:
  level: detail
  layer: session
  title: 区间 ${session_id} - Fling 阶段
  columns:
  - name: phase
    label: 阶段
    type: string
  - name: frame_count
    label: 帧数
    type: number
    format: compact
  - name: janky_count
    label: 掉帧数
    type: number
    format: compact
  - name: jank_rate
    label: 掉帧率
    type: percentage
    format: percentage
  - name: avg_frame_ms
    label: 平均帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: max_frame_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: fps
    label: FPS
    type: number
  - name: duration_ms
    label: 持续时间
    type: duration
    format: duration_ms
    unit: ms
save_as: fling_stats
condition: has_fling == 1
```
### 识别掉帧

- ID: `identify_janky_frames`
- Type: `atomic`
- SQL: [`../sql/scroll_session_analysis/identify_janky_frames.sql`](../sql/scroll_session_analysis/identify_janky_frames.sql)

```yaml
id: identify_janky_frames
type: atomic
display:
  level: detail
  layer: list
  title: 掉帧列表 (区间 ${session_id})
  columns:
  - name: frame_number
    label: 帧号
    type: number
  - name: phase
    label: 阶段
    type: string
  - name: ts_str
    label: 开始时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: jank_level
    label: 卡顿等级
    type: string
  - name: frames_dropped
    label: 丢帧数
    type: number
save_as: janky_frames
```
### 掉帧原因分析

- ID: `analyze_janky_frames`
- Type: `iterator`

```yaml
id: analyze_janky_frames
type: iterator
source: janky_frames
item_skill: jank_frame_detail
item_params:
  start_ts: ts_str
  end_ts: end_ts_str
  dur_ms: dur_ms
display:
  level: key
  layer: deep
  title: 掉帧原因分析 (区间 ${session_id})
  format: table
  columns:
  - name: frame_number
    label: 帧号
    type: number
  - name: phase
    label: 阶段
    type: string
  - name: dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
  - name: diagnosis
    label: 诊断
    type: string
  - name: confidence
    label: 置信度
    type: percentage
    format: percentage
save_as: frame_diagnostics
max_items: 10
filter: jank_level == 'severe' OR jank_level == 'bad'
```
### 区间诊断

- ID: `session_diagnosis`
- Type: `diagnostic`

```yaml
id: session_diagnosis
type: diagnostic
display:
  level: summary
  layer: session
  title: 区间 ${session_id} 诊断
inputs:
- full_stats
- touch_stats
- fling_stats
- janky_frames
rules:
- condition: full_stats.data[0].jank_rate > 15
  severity: critical
  diagnosis: 滑动掉帧率过高 (${full_stats.data[0].jank_rate}%)
  confidence: high
  suggestions:
  - 检查主线程耗时操作
  - 优化列表项布局复杂度
  - 使用 RecyclerView 的 setHasFixedSize 和 setItemViewCacheSize
- condition: full_stats.data[0].jank_rate > 5
  severity: warning
  diagnosis: 滑动存在掉帧 (${full_stats.data[0].jank_rate}%)
  confidence: medium
  suggestions:
  - 检查 onBindViewHolder 耗时
  - 避免在滑动时加载图片
- condition: full_stats.data[0].max_frame_ms > 100
  severity: critical
  diagnosis: 存在严重卡顿帧 (最大 ${full_stats.data[0].max_frame_ms}ms)
  confidence: high
  suggestions:
  - 检查是否有 IO 操作在主线程
  - 检查是否有同步 Binder 调用
  - 分析可能的 ANR 风险
- condition: touch_stats.data[0].jank_rate > ${fling_stats.data[0].jank_rate} * 2
  severity: warning
  diagnosis: 按压滑动阶段掉帧更严重
  confidence: medium
  suggestions:
  - 检查 dispatchTouchEvent 链路
  - 优化手势响应代码
- condition: fling_stats.data[0].jank_rate > ${touch_stats.data[0].jank_rate} * 2
  severity: warning
  diagnosis: Fling 阶段掉帧更严重
  confidence: medium
  suggestions:
  - 检查 Fling 动画计算
  - 优化滑动曲线计算逻辑
- condition: full_stats.data[0].estimated_fps < 50
  severity: warning
  diagnosis: 帧率偏低 (${full_stats.data[0].estimated_fps} fps)
  confidence: medium
  suggestions:
  - 优化 onDraw 方法
  - 减少过度绘制
  - 使用硬件加速
```
## Output and evidence contract

```yaml
display:
  level: summary
  format: summary
fields:
- name: session_id
  label: 区间
- name: duration_ms
  label: 时长(ms)
- name: total_frames
  label: 总帧数
- name: janky_frames
  label: 掉帧数
- name: jank_rate
  label: 掉帧率(%)
- name: estimated_fps
  label: 帧率(fps)
- name: touch_fps
  label: 按压帧率
  source: touch_stats.data[0].fps
- name: fling_fps
  label: Fling帧率
  source: fling_stats.data[0].fps
```
