GENERATED FILE - DO NOT EDIT.
Source: backend/skills/modules/framework/choreographer_module.skill.yaml
Source SHA-256: 4a35f45abe4b7e038dbbcded10d22da6cb28b79dbd7a66e0e9d83452c778e916
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Choreographer 分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: choreographer_module
version: '1.0'
type: composite
category: framework
```

## Metadata

```yaml
display_name: Choreographer 分析
description: 分析 VSYNC 时序、doFrame 回调和渲染流水线
tags:
- framework
- choreographer
- vsync
- frame
- render
- pipeline
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: Target package name
- name: vsync_period_ns
  type: number
  required: false
  description: 'VSync period in nanoseconds (default: 16666667 for 60Hz)'
```

## Module contract

```yaml
layer: framework
component: Choreographer
subsystems:
- vsync
- doframe
- input_callback
- animation_callback
- traversal_callback
relatedModules:
- framework_surfaceflinger
- app_third_party
- hardware_gpu
```

## Dialogue guidance

```yaml
capabilities:
- id: frame_timing_analysis
  questionTemplate: What is the frame timing for package {package}?
  requiredParams:
  - package
  description: Analyze doFrame timing and breakdown
- id: vsync_analysis
  questionTemplate: What is the VSYNC timing pattern?
  requiredParams: []
  description: Analyze VSYNC signal timing
- id: callback_breakdown
  questionTemplate: What is the doFrame callback breakdown for {package}?
  requiredParams:
  - package
  description: Analyze Input/Animation/Traversal timing
- id: frame_drop_analysis
  questionTemplate: Why were frames dropped for {package}?
  requiredParams:
  - package
  description: Analyze frame drop causes
findingsSchema:
- id: long_doframe
  severity: critical
  titleTemplate: 'Long doFrame: {dur_ms}ms (exceeds frame budget)'
  descriptionTemplate: doFrame exceeded frame budget by {exceed_ms}ms
  evidenceFields:
  - dur_ms
  - exceed_ms
  - main_contributor
- id: input_callback_slow
  severity: warning
  titleTemplate: 'Slow input callback: {dur_ms}ms'
  descriptionTemplate: Input callback processing took {dur_ms}ms
  evidenceFields:
  - dur_ms
  - frame_ts
- id: animation_callback_slow
  severity: warning
  titleTemplate: 'Slow animation callback: {dur_ms}ms'
  descriptionTemplate: Animation callback took {dur_ms}ms
  evidenceFields:
  - dur_ms
  - frame_ts
- id: traversal_callback_slow
  severity: warning
  titleTemplate: 'Slow traversal (measure/layout/draw): {dur_ms}ms'
  descriptionTemplate: View traversal took {dur_ms}ms
  evidenceFields:
  - dur_ms
  - measure_ms
  - layout_ms
  - draw_ms
- id: vsync_jitter
  severity: warning
  titleTemplate: 'VSYNC jitter detected: {jitter_ms}ms'
  descriptionTemplate: VSYNC timing inconsistent, affecting frame pacing
  evidenceFields:
  - jitter_ms
  - avg_period_ms
  - expected_period_ms
suggestionsSchema:
- id: check_main_thread_blocking
  condition: dur_ms > 32
  targetModule: scheduler_module
  questionTemplate: What was blocking main thread during frame {frame_ts}?
  paramsMapping:
    ts: frame_ts
    package: package
  priority: 1
- id: check_gpu_rendering
  condition: traversal_dur_ms > 16
  targetModule: gpu_module
  questionTemplate: What was GPU doing during frame rendering?
  paramsMapping: {}
  priority: 2
- id: check_surfaceflinger
  condition: frame_dropped == true
  targetModule: surfaceflinger_module
  questionTemplate: Did SurfaceFlinger contribute to frame drop?
  paramsMapping: {}
  priority: 1
```

## Ordered execution

### doFrame 概览

- ID: `doframe_overview`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/doframe_overview.sql`](../sql/choreographer_module/doframe_overview.sql)

```yaml
id: doframe_overview
type: atomic
display:
  level: key
  layer: overview
  title: 帧渲染概览
save_as: doframe_overview
synthesize:
  role: overview
  fields:
  - key: total_frames
    label: 总帧数
  - key: avg_dur_ms
    label: 平均帧时间
    format: '{{value}}ms'
  - key: jank_frames
    label: 卡顿帧
  - key: jank_rate_pct
    label: 卡顿率
    format: '{{value}}%'
```
### 帧时间线

- ID: `doframe_timeline`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/doframe_timeline.sql`](../sql/choreographer_module/doframe_timeline.sql)

```yaml
id: doframe_timeline
type: atomic
display:
  level: detail
  layer: list
  title: 帧时间线
save_as: doframe_timeline
```
### 回调耗时分解

- ID: `callback_breakdown`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/callback_breakdown.sql`](../sql/choreographer_module/callback_breakdown.sql)

```yaml
id: callback_breakdown
type: atomic
display:
  level: detail
  layer: overview
  title: 回调耗时分布
save_as: callback_breakdown
synthesize: true
```
### VSYNC 时序

- ID: `vsync_timing`
- Type: `skill`

```yaml
id: vsync_timing
type: skill
skill: vsync_period_detection
display:
  level: detail
  layer: overview
  title: VSYNC 统计
save_as: vsync_timing
```
### 长帧分析

- ID: `long_frames`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/long_frames.sql`](../sql/choreographer_module/long_frames.sql)

```yaml
id: long_frames
type: atomic
display:
  level: detail
  layer: list
  title: 长帧列表
save_as: long_frames
```
### View 遍历分析

- ID: `view_traversal`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/view_traversal.sql`](../sql/choreographer_module/view_traversal.sql)

```yaml
id: view_traversal
type: atomic
display:
  level: detail
  layer: overview
  title: View 遍历耗时
save_as: view_traversal
```
### 帧流水线

- ID: `frame_pipeline`
- Type: `atomic`
- SQL: [`../sql/choreographer_module/frame_pipeline.sql`](../sql/choreographer_module/frame_pipeline.sql)

```yaml
id: frame_pipeline
type: atomic
display:
  level: detail
  layer: list
  title: 帧流水线阶段
save_as: frame_pipeline
```
### Choreographer 诊断

- ID: `choreographer_diagnosis`
- Type: `diagnostic`

```yaml
id: choreographer_diagnosis
type: diagnostic
inputs:
- doframe_overview
- callback_breakdown
- long_frames
- view_traversal
rules:
- condition: doframe_overview.data[0]?.jank_rate_pct > 10
  diagnosis: 卡顿率 ${doframe_overview.data[0]?.jank_rate_pct}%，超过 10% 阈值
  confidence: critical
  suggestions:
  - 分析卡顿帧的具体原因
  - 优化主线程耗时操作
  - 检查是否有同步 Binder 调用
  evidence_fields:
  - doframe_overview.data[0]?.jank_rate_pct
  - doframe_overview.data[0]?.jank_frames
  - doframe_overview.data[0]?.total_frames
- condition: doframe_overview.data[0]?.max_dur_ms > 100
  diagnosis: 最长帧时间 ${doframe_overview.data[0]?.max_dur_ms}ms，严重影响体验
  confidence: critical
  suggestions:
  - 分析该帧的详细调用栈
  - 检查是否有 ANR 风险
  evidence_fields:
  - doframe_overview.data[0]?.max_dur_ms
- condition: callback_breakdown.data.find(c => c.callback_type === 'traversal')?.avg_ms > 10
  diagnosis: View 遍历平均耗时 ${callback_breakdown.data.find(c => c.callback_type === 'traversal')?.avg_ms}ms
  confidence: high
  suggestions:
  - 减少 View 层级
  - 使用 ConstraintLayout 替代嵌套布局
  - 避免在 onDraw 中分配对象
  evidence_fields:
  - callback_breakdown.data.find(c => c.callback_type === 'traversal')?.avg_ms
- condition: view_traversal.data.find(v => v.traversal_phase === 'measure')?.max_ms > 8
  diagnosis: Measure 阶段最大耗时 ${view_traversal.data.find(v => v.traversal_phase === 'measure')?.max_ms}ms
  confidence: medium
  suggestions:
  - 检查 View 树复杂度
  - 避免在 onMeasure 中进行耗时计算
  evidence_fields:
  - view_traversal.data.find(v => v.traversal_phase === 'measure')?.max_ms
- condition: long_frames.data.filter(f => f.jank_severity === 'jank_5plus_frames').length > 0
  diagnosis: 检测到 ${long_frames.data.filter(f => f.jank_severity === 'jank_5plus_frames').length} 个严重卡顿帧 (丢失 5+ 帧)
  confidence: critical
  suggestions:
  - 这些帧可能导致明显卡顿感知
  - 需要重点分析这些时间点
  evidence_fields:
  - long_frames.data.filter(f => f.jank_severity === 'jank_5plus_frames').length
display:
  level: key
  layer: overview
  title: Choreographer 诊断结果
```
