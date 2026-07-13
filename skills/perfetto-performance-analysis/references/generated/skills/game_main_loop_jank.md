GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/game_main_loop_jank.skill.yaml
Source SHA-256: 174f4c55bf6e3f9deed54eb0413221f154230454cb2b49437a87e6831cd3a251
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 游戏主循环卡顿检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: game_main_loop_jank
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 游戏主循环卡顿检测
description: 检测 Unity/Unreal/Cocos/Godot 主循环、Tick、渲染线程中的超预算帧切片
icon: sports_esports
tags:
- game
- unity
- unreal
- cocos
- main_loop
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - 游戏主循环
  - Unity Update
  - Unreal Tick
  - Cocos director
  - 游戏 Tick
  - 游戏卡顿
  en:
  - game main loop
  - unity update
  - unreal tick
  - cocos director
  - game tick
patterns:
- .*(游戏|Unity|Unreal|Cocos).*(主循环|Tick|Update|卡顿).*
- .*(game|unity|unreal|cocos).*(main loop|tick|update|jank).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
modules:
- slices.with_context
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: process_name
  type: string
  required: false
  description: 目标进程名别名；当 package 为空时使用
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: target_frame_ms
  type: number
  required: false
  description: 目标帧预算(ms)，默认 16.67
```

## Ordered execution

### 游戏主循环汇总

- ID: `engine_loop_summary`
- Type: `atomic`
- SQL: [`../sql/game_main_loop_jank/engine_loop_summary.sql`](../sql/game_main_loop_jank/engine_loop_summary.sql)

```yaml
id: engine_loop_summary
type: atomic
display:
  level: summary
  layer: overview
  title: 游戏主循环 / Tick 汇总
  columns:
  - name: engine_family
    label: 引擎
    type: string
  - name: phase
    label: 阶段
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: slice_count
    label: 次数
    type: number
    format: compact
  - name: total_dur_ms
    label: 总耗时
    type: duration
    format: duration_ms
  - name: avg_dur_ms
    label: 平均耗时
    type: duration
    format: duration_ms
  - name: p95_dur_ms
    label: P95耗时
    type: duration
    format: duration_ms
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: over_budget_count
    label: 超预算次数
    type: number
    format: compact
  - name: rating
    label: 评级
    type: string
save_as: engine_loop_summary
```
### 慢主循环切片

- ID: `slow_engine_slices`
- Type: `atomic`
- SQL: [`../sql/game_main_loop_jank/slow_engine_slices.sql`](../sql/game_main_loop_jank/slow_engine_slices.sql)

```yaml
id: slow_engine_slices
type: atomic
display:
  level: detail
  layer: list
  title: 慢游戏主循环 / Tick 切片
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: engine_family
    label: 引擎
    type: string
  - name: phase
    label: 阶段
    type: string
  - name: slice_name
    label: Slice
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
save_as: slow_engine_slices
```
## Output and evidence contract

```yaml
format: structured
```
