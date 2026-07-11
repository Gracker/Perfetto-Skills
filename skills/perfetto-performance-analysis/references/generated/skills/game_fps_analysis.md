GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/game_fps_analysis.skill.yaml
Source SHA-256: 149fad0ed589259b19b7d70e8969cf12c77fc86255551b55aeea19b9705ed7fe
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 游戏帧率分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: game_fps_analysis
version: '1.0'
type: atomic
category: rendering
tier: A
priority: high
```

## Metadata

```yaml
display_name: 游戏帧率分析
description: 针对游戏的帧率分析，支持 30/45/60fps 固定帧率模式
icon: gamepad
tags:
- game
- fps
- frame
- performance
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 游戏
  - FPS
  - 帧率
  - Unity
  - Unreal
  - Cocos
  - 游戏卡顿
  en:
  - game fps
  - frame rate
  - unity
  - unreal
  - cocos
  - game jank
patterns:
- .*(游戏|Unity|Unreal|Cocos).*(FPS|帧率|卡顿).*
- .*(game|unity|unreal).*(fps|frame rate|jank).*
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
- process
optional_tables:
- expected_frame_timeline_slice
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名
- name: target_fps
  type: integer
  required: false
  description: 目标帧率 (30/45/60)，不填则自动检测
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
```

## Ordered execution

### 检测目标帧率

- ID: `detect_target_fps`
- Type: `atomic`
- SQL: [`../sql/game_fps_analysis/detect_target_fps.sql`](../sql/game_fps_analysis/detect_target_fps.sql)

```yaml
id: detect_target_fps
type: atomic
display:
  level: summary
  title: 目标帧率检测
  columns:
  - name: detected_fps_mode
    label: 检测模式
    type: string
  - name: target_interval_ns
    label: 目标间隔
    type: duration
    format: duration_ms
    unit: ns
  - name: target_fps
    label: 目标帧率
    type: number
  - name: frames_at_target
    label: 达标帧数
    type: number
    format: compact
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: target_hit_rate
    label: 达标率
    type: percentage
    format: percentage
save_as: fps_detection
```
### 帧间隔统计

- ID: `frame_interval_stats`
- Type: `atomic`
- SQL: [`../sql/game_fps_analysis/frame_interval_stats.sql`](../sql/game_fps_analysis/frame_interval_stats.sql)

```yaml
id: frame_interval_stats
type: atomic
display:
  level: detail
  title: 帧间隔分析
  columns:
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: duration_sec
    label: 时长(秒)
    type: number
  - name: actual_fps
    label: 实际FPS
    type: number
  - name: avg_interval_ms
    label: 平均间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: min_interval_ms
    label: 最小间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: max_interval_ms
    label: 最大间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: p50_interval_ms
    label: P50间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: p95_interval_ms
    label: P95间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: interval_stddev_ms
    label: 间隔标准差
    type: duration
    format: duration_ms
    unit: ms
save_as: interval_stats
```
### 掉帧检测

- ID: `jank_detection`
- Type: `atomic`
- SQL: [`../sql/game_fps_analysis/jank_detection.sql`](../sql/game_fps_analysis/jank_detection.sql)

```yaml
id: jank_detection
type: atomic
display:
  level: detail
  title: 掉帧分析
  columns:
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: jank_count
    label: 掉帧数
    type: number
    format: compact
  - name: severe_jank_count
    label: 严重掉帧
    type: number
    format: compact
  - name: freeze_count
    label: 卡顿数
    type: number
    format: compact
  - name: jank_rate
    label: 掉帧率
    type: percentage
    format: percentage
  - name: severe_jank_rate
    label: 严重掉帧率
    type: percentage
    format: percentage
  - name: target_interval_ms
    label: 目标间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: target_fps
    label: 目标帧率
    type: number
  - name: quality_rating
    label: 质量评级
    type: string
save_as: jank_stats
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: fps_detection
  description: 目标帧率检测结果
- name: interval_stats
  description: 帧间隔统计
- name: jank_stats
  description: 掉帧统计
```

## Thresholds

```yaml
jank_rate:
  unit: '%'
  description: 掉帧率
  levels:
    excellent:
      max: 1
    good:
      min: 1
      max: 5
    warning:
      min: 5
      max: 10
    critical:
      min: 10
```
