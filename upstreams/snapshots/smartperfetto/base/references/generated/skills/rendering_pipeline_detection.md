GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
Source SHA-256: 89f9bbab94bb6089b6a022e187c43002cbddfee4b0cb0c728c50f2d79ace3457
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 渲染管线检测 (YAML 驱动)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: rendering_pipeline_detection
version: '4.0'
type: composite
category: rendering
tier: S
```

## Metadata

```yaml
display_name: 渲染管线检测 (YAML 驱动)
description: 从 catalog 与 pipeline YAML 生成子路径评分、主出图类型、候选与正交特性
icon: layers
tags:
- rendering
- pipeline
- detection
- teaching
- yaml
```

## Triggers

```yaml
keywords:
  zh:
  - 渲染管线
  - 管线检测
  - 出图类型
  - SurfaceView
  - TextureView
  - Flutter
  - WebView
  en:
  - rendering pipeline
  - rendering type
  - pipeline detection
  - surfaceview
  - textureview
  - flutter
  - webview
patterns:
- .*(渲染管线|出图类型|SurfaceView|TextureView|WebView|Flutter).*
- .*(rendering pipeline|rendering type|surfaceview|textureview|webview|flutter).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread_track
- thread
- process
optional_tables:
- counter
- counter_track
modules:
- slices.with_context
- android.frames.timeline
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 应用包名 (可选，用于过滤)
```

## Ordered execution

### 计算管线类型评分 (YAML 驱动)

- ID: `score_pipelines`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/score_pipelines.sql`](../sql/rendering_pipeline_detection/score_pipelines.sql)

```yaml
id: score_pipelines
type: atomic
display:
  level: detail
  title: 管线类型评分
save_as: pipeline_scores
```
### 确定主管线 (YAML 驱动)

- ID: `determine_pipeline`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/determine_pipeline.sql`](../sql/rendering_pipeline_detection/determine_pipeline.sql)

```yaml
id: determine_pipeline
type: atomic
display:
  level: summary
  title: 渲染管线识别结果
save_as: pipeline_result
```
### 确定子变体

- ID: `subvariants`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/subvariants.sql`](../sql/rendering_pipeline_detection/subvariants.sql)

```yaml
id: subvariants
type: atomic
display:
  level: detail
  title: 子变体检测
save_as: subvariants
```
### 检查采集完整性

- ID: `trace_requirements`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/trace_requirements.sql`](../sql/rendering_pipeline_detection/trace_requirements.sql)

```yaml
id: trace_requirements
type: atomic
display:
  level: detail
  title: 采集建议
save_as: trace_requirements
```
### 识别活跃渲染进程

- ID: `active_rendering_processes`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/active_rendering_processes.sql`](../sql/rendering_pipeline_detection/active_rendering_processes.sql)

```yaml
id: active_rendering_processes
type: atomic
display:
  level: detail
  title: 活跃渲染进程
save_as: active_rendering_processes
```
### SF Layer 数与名字模式 (辅助证据)

- ID: `layer_signals`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/layer_signals.sql`](../sql/rendering_pipeline_detection/layer_signals.sql)

```yaml
id: layer_signals
type: atomic
display:
  level: detail
  title: Layer 信号
save_as: layer_signals
```
### 额外节奏源 (辅助证据)

- ID: `extra_rhythm_signals`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/extra_rhythm_signals.sql`](../sql/rendering_pipeline_detection/extra_rhythm_signals.sql)

```yaml
id: extra_rhythm_signals
type: atomic
display:
  level: detail
  title: 额外节奏源
save_as: extra_rhythm_signals
```
### BufferQueue 路径证据

- ID: `bufferqueue_path_signals`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/bufferqueue_path_signals.sql`](../sql/rendering_pipeline_detection/bufferqueue_path_signals.sql)

```yaml
id: bufferqueue_path_signals
type: atomic
display:
  level: detail
  title: BufferQueue 路径
save_as: bufferqueue_path_signals
```
## Output and evidence contract

```yaml
fields:
- name: pipeline_scores
  label: 各管线类型得分 (调试用)
- name: pipeline_result
  label: 主管线识别结果
- name: subvariants
  label: 子变体信息
- name: trace_requirements
  label: 采集完整性检查
- name: active_rendering_processes
  label: 活跃渲染进程列表 (用于智能 Pin)
- name: layer_signals
  label: Layer 信号 (SF 侧 layer 数与命名模式)
- name: extra_rhythm_signals
  label: 额外节奏源 (Swappy/AChoreographer/Camera/Codec)
- name: bufferqueue_path_signals
  label: BufferQueue 路径分型
```
