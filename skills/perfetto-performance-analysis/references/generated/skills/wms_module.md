GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/wms_module.skill.yaml
Source SHA-256: ec088f394851b6fb0426109a0105b0d0ae930adf759b15011ab45a18a1a5831f
Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880
# WMS 窗口管理分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: wms_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: WMS 窗口管理分析
description: 分析窗口动画、Activity 转场和窗口状态变化
tags:
- framework
- wms
- window
- animation
- transition
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
optional_tables:
- window_manager_shell_transitions
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: ts
  type: timestamp
  required: false
  description: Target timestamp
- name: start_ts
  type: timestamp
  required: false
  description: Analysis start timestamp
- name: end_ts
  type: timestamp
  required: false
  description: Analysis end timestamp
```

## Module contract

```yaml
layer: framework
component: WMS
subsystems:
- window_animation
- activity_transition
- window_state
- display_management
relatedModules:
- framework_ams
- framework_surfaceflinger
- framework_input
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: window_animation_analysis
  questionTemplate: What window animations happened for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze window open/close/transition animations
- id: activity_transition_timing
  questionTemplate: What is the activity transition timing for package {package}?
  requiredParams:
  - package
  description: Analyze activity transition animation duration
- id: window_state_changes
  questionTemplate: What window state changes happened at timestamp {ts}?
  requiredParams:
  - ts
  optionalParams:
  - package
  description: Track window visibility and focus changes
- id: slow_window_animation
  questionTemplate: Why was window animation slow for package {package}?
  requiredParams:
  - package
  description: Diagnose slow window animations
findingsSchema:
- id: slow_window_animation
  severity: warning
  titleTemplate: 'Slow window animation: {animation_type} took {dur_ms}ms'
  descriptionTemplate: Window animation exceeded smooth threshold ({dur_ms}ms > 300ms)
  evidenceFields:
  - animation_type
  - dur_ms
  - window_name
  - expected_ms
- id: animation_frame_drop
  severity: critical
  titleTemplate: 'Animation frame drop: {dropped_frames} frames during {animation_type}'
  descriptionTemplate: Window animation dropped {dropped_frames} frames causing jank
  evidenceFields:
  - animation_type
  - dropped_frames
  - total_frames
- id: window_focus_delay
  severity: warning
  titleTemplate: 'Window focus delay: {delay_ms}ms'
  descriptionTemplate: Window took {delay_ms}ms to gain focus after request
  evidenceFields:
  - delay_ms
  - window_name
- id: transition_overlap
  severity: info
  titleTemplate: Transition overlap detected
  descriptionTemplate: Multiple window transitions happening simultaneously
  evidenceFields:
  - transition_count
  - overlap_duration_ms
suggestionsSchema:
- id: check_surfaceflinger
  condition: animation_frame_drop > 0
  targetModule: surfaceflinger_module
  questionTemplate: What caused frame drops during window animation?
  paramsMapping:
    start_ts: animation_start_ts
    end_ts: animation_end_ts
  priority: 1
- id: check_main_thread
  condition: dur_ms > 300
  targetModule: scheduler_module
  questionTemplate: Why was main thread slow during window animation for {package}?
  paramsMapping:
    package: package
  priority: 1
- id: check_gpu_during_animation
  condition: animation_type contains 'transition'
  targetModule: gpu_module
  questionTemplate: What was GPU utilization during window transition?
  paramsMapping: {}
  priority: 2
```

## Ordered execution

### 窗口动画概览

- ID: `window_animation_overview`
- Type: `atomic`
- SQL: [`../sql/wms_module/window_animation_overview.sql`](../sql/wms_module/window_animation_overview.sql)

```yaml
id: window_animation_overview
type: atomic
display:
  level: key
  layer: overview
  title: 窗口动画统计
save_as: animation_overview
synthesize:
  role: overview
  fields:
  - key: animation_type
    label: 动画类型
  - key: animation_count
    label: 次数
  - key: avg_dur_ms
    label: 平均耗时
    format: '{{value}}ms'
```
### Activity 转场分析

- ID: `activity_transitions`
- Type: `atomic`
- SQL: [`../sql/wms_module/activity_transitions.sql`](../sql/wms_module/activity_transitions.sql)

```yaml
id: activity_transitions
type: atomic
display:
  level: detail
  layer: list
  title: Activity 转场事件
save_as: transitions
```
### 窗口状态变化

- ID: `window_state_changes`
- Type: `atomic`
- SQL: [`../sql/wms_module/window_state_changes.sql`](../sql/wms_module/window_state_changes.sql)

```yaml
id: window_state_changes
type: atomic
display:
  level: detail
  layer: list
  title: 窗口状态变化
save_as: state_changes
```
### 慢动画检测

- ID: `slow_animations`
- Type: `atomic`
- SQL: [`../sql/wms_module/slow_animations.sql`](../sql/wms_module/slow_animations.sql)

```yaml
id: slow_animations
type: atomic
display:
  level: detail
  layer: list
  title: 慢窗口动画
save_as: slow_animations
```
### 窗口绘制延迟

- ID: `window_draw_latency`
- Type: `atomic`
- SQL: [`../sql/wms_module/window_draw_latency.sql`](../sql/wms_module/window_draw_latency.sql)

```yaml
id: window_draw_latency
type: atomic
display:
  level: detail
  layer: list
  title: 窗口绘制耗时
save_as: draw_latency
```
### WMS 诊断

- ID: `wms_diagnosis`
- Type: `diagnostic`

```yaml
id: wms_diagnosis
type: diagnostic
inputs:
- animation_overview
- transitions
- slow_animations
- draw_latency
rules:
- condition: slow_animations.data.length > 0
  diagnosis: 检测到 ${slow_animations.data.length} 个慢窗口动画，最长 ${slow_animations.data[0]?.dur_ms}ms
  confidence: high
  suggestions:
  - 检查动画期间是否有主线程阻塞
  - 检查 GPU 渲染负载
  - 考虑简化动画效果
  evidence_fields:
  - slow_animations.data.length
  - slow_animations.data[0]?.dur_ms
  - slow_animations.data[0]?.animation_type
- condition: transitions.data.filter(t => t.quality === 'very_slow').length > 3
  diagnosis: 多个 Activity 转场过慢 (>500ms)
  confidence: high
  suggestions:
  - 检查 Activity 生命周期中的耗时操作
  - 优化首帧渲染性能
  evidence_fields:
  - transitions.data[0]?.dur_ms
  - transitions.data[0]?.transition_type
- condition: animation_overview.data[0]?.max_dur_ms > 500
  diagnosis: 窗口动画最大耗时 ${animation_overview.data[0]?.max_dur_ms}ms，超过 500ms 阈值
  confidence: medium
  suggestions:
  - 分析具体动画场景
  - 检查系统负载情况
  evidence_fields:
  - animation_overview.data[0]?.animation_type
  - animation_overview.data[0]?.max_dur_ms
- condition: draw_latency.data[0]?.avg_dur_ms > 16
  diagnosis: 应用窗口绘制平均耗时 ${draw_latency.data[0]?.avg_dur_ms}ms，超过 16ms 帧时间
  confidence: medium
  suggestions:
  - 优化 onDraw 实现
  - 减少过度绘制
  - 使用硬件加速
  evidence_fields:
  - draw_latency.data[0]?.draw_event
  - draw_latency.data[0]?.avg_dur_ms
display:
  level: key
  layer: overview
  title: WMS 诊断结果
```
