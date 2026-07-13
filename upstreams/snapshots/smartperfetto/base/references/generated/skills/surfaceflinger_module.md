GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/surfaceflinger_module.skill.yaml
Source SHA-256: d456d7df46f6aec95de47a77dc360d10ac0154b45fa9ed8e8a779c8ea356bffd
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# SurfaceFlinger 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: surfaceflinger_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: SurfaceFlinger 分析
description: 分析帧渲染时序、卡顿原因和 GPU 合成
tags:
- framework
- surfaceflinger
- frame
- jank
- render
```

## Prerequisites

```yaml
modules:
- android.frames.timeline
- android.frames.jank_type
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: frame_id
  type: number
  required: false
  description: Specific frame ID to analyze
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
component: SurfaceFlinger
subsystems:
- vsync
- composition
- layer
relatedModules:
- hardware_gpu
- framework_wms
- app_third_party
```

## Dialogue guidance

```yaml
capabilities:
- id: frame_jank_analysis
  questionTemplate: Why did frame {frame_id} jank for package {package}?
  requiredParams:
  - frame_id
  - package
  description: Analyze the root cause of a specific janky frame
- id: scroll_performance
  questionTemplate: What is the scroll performance for package {package}?
  requiredParams:
  - package
  optionalParams:
  - start_ts
  - end_ts
  description: Analyze scrolling smoothness and frame drops
- id: composition_time
  questionTemplate: How long did GPU composition take for {layer}?
  requiredParams:
  - layer
  description: Analyze GPU composition timing
findingsSchema:
- id: high_jank_rate
  severity: critical
  titleTemplate: 'High jank rate: {jank_rate}% ({jank_count}/{total_frames} frames)'
  descriptionTemplate: Frame drop rate of {jank_rate}% exceeds acceptable threshold
  evidenceFields:
  - jank_rate
  - jank_count
  - total_frames
  - avg_fps
- id: main_thread_delay
  severity: warning
  titleTemplate: Main thread caused {main_thread_jank} frame drops
  descriptionTemplate: Main thread work exceeded frame budget {main_thread_jank} times
  evidenceFields:
  - main_thread_jank
  - avg_main_ms
- id: render_thread_delay
  severity: warning
  titleTemplate: Render thread caused {render_thread_jank} frame drops
  descriptionTemplate: GPU rendering exceeded budget {render_thread_jank} times
  evidenceFields:
  - render_thread_jank
  - avg_render_ms
suggestionsSchema:
- id: check_main_thread
  condition: main_thread_jank > render_thread_jank
  targetModule: scheduler_module
  questionTemplate: Why was main thread slow during frames?
  paramsMapping:
    tid: main_tid
  priority: 1
- id: check_gpu
  condition: render_thread_jank > main_thread_jank
  targetModule: hardware_gpu_module
  questionTemplate: Why was GPU rendering slow?
  paramsMapping:
    package: package
  priority: 1
- id: check_binder_in_frame
  condition: binder_during_frame > 0
  targetModule: binder_module
  questionTemplate: What Binder calls happened during frame rendering?
  paramsMapping:
    package: package
  priority: 2
```

## Ordered execution

### 帧统计概览

- ID: `frame_overview`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_module/frame_overview.sql`](../sql/surfaceflinger_module/frame_overview.sql)

```yaml
id: frame_overview
type: atomic
display:
  level: key
  layer: overview
  title: 帧统计概览
save_as: frame_stats
synthesize:
  role: overview
  fields:
  - key: total_frames
    label: 总帧数
  - key: jank_count
    label: 卡顿帧数
  - key: jank_rate
    label: 卡顿率
    format: '{{value}}%'
  - key: avg_fps
    label: 平均帧率
    format: '{{value}} FPS'
```
### 卡顿类型分布

- ID: `jank_breakdown`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_module/jank_breakdown.sql`](../sql/surfaceflinger_module/jank_breakdown.sql)

```yaml
id: jank_breakdown
type: atomic
display:
  level: detail
  layer: list
  title: 卡顿类型分布
save_as: jank_types
synthesize:
  role: list
  groupBy:
  - field: jank_type
    title: 卡顿类型
```
### 线程耗时分布

- ID: `thread_timing`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_module/thread_timing.sql`](../sql/surfaceflinger_module/thread_timing.sql)

```yaml
id: thread_timing
type: atomic
display:
  level: detail
  layer: overview
  title: 线程耗时分布
save_as: thread_stats
synthesize: true
```
### 最差帧列表

- ID: `worst_frames`
- Type: `atomic`
- SQL: [`../sql/surfaceflinger_module/worst_frames.sql`](../sql/surfaceflinger_module/worst_frames.sql)

```yaml
id: worst_frames
type: atomic
display:
  level: detail
  layer: list
  title: 最差帧列表
save_as: worst_frames
```
### 帧诊断

- ID: `frame_diagnosis`
- Type: `diagnostic`

```yaml
id: frame_diagnosis
type: diagnostic
inputs:
- frame_stats
- jank_types
- thread_stats
rules:
- condition: frame_stats.data[0]?.jank_rate > 10
  diagnosis: 卡顿率过高 (${frame_stats.data[0]?.jank_rate}%)，用户体验受影响
  confidence: high
  suggestions:
  - 分析具体卡顿帧找出根因
  - 减少主线程工作量
  evidence_fields:
  - frame_stats.data[0].jank_rate
  - frame_stats.data[0].jank_count
- condition: thread_stats.data.find(t => t.thread === 'MainThread')?.overrun_count > 5
  diagnosis: 主线程频繁超时 (${thread_stats.data.find(t => t.thread === 'MainThread')?.overrun_count} 次)，应用逻辑耗时
  confidence: high
  suggestions:
  - 检查主线程是否有耗时操作
  - 将耗时操作移至后台线程
  evidence_fields:
  - thread_stats.data[0].avg_ms
  - thread_stats.data[0].overrun_count
- condition: thread_stats.data.find(t => t.thread === 'RenderThread')?.overrun_count > 5
  diagnosis: 渲染线程频繁超时 (${thread_stats.data.find(t => t.thread === 'RenderThread')?.overrun_count} 次)，GPU 负载高
  confidence: high
  suggestions:
  - 减少过度绘制
  - 优化 View 层级
  evidence_fields:
  - thread_stats.data[1].avg_ms
  - thread_stats.data[1].overrun_count
- condition: jank_types.data[0]?.jank_cause?.includes('Binder')
  diagnosis: Binder 调用导致卡顿 (${jank_types.data[0]?.count} 次)
  confidence: medium
  suggestions:
  - 检查帧渲染期间的 Binder 调用
  - 考虑缓存或异步处理
  evidence_fields:
  - jank_types.data[0].jank_cause
  - jank_types.data[0].count
display:
  level: key
  layer: overview
  title: 帧诊断结果
```
