GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/rendering_pipeline_detection.skill.yaml
Source SHA-256: daafcab67c375034945bafa954cdc6e4dc9e1a61942fb303a42d6abf593d817a
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# 渲染管线检测 (24 类型)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: rendering_pipeline_detection
version: '2.0'
type: composite
category: rendering
tier: S
```

## Metadata

```yaml
display_name: 渲染管线检测 (24 类型)
description: 细粒度识别应用使用的渲染管线类型，输出主链路+候选+特性
icon: layers
tags:
- rendering
- pipeline
- detection
- teaching
```

## Triggers

```yaml
keywords:
  zh:
  - 渲染管线
  - 管线检测
  - SurfaceView
  - TextureView
  - Flutter
  - WebView
  - 游戏渲染
  en:
  - rendering pipeline
  - pipeline detection
  - surfaceview
  - textureview
  - flutter
  - webview
patterns:
- .*(渲染管线|SurfaceView|TextureView|WebView|Flutter).*
- .*(rendering pipeline|surfaceview|textureview|webview|flutter).*
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

### 采集线程信号

- ID: `thread_signals`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/thread_signals.sql`](../sql/rendering_pipeline_detection/thread_signals.sql)

```yaml
id: thread_signals
type: atomic
display:
  level: detail
  title: 线程特征检测
save_as: thread_signals
```
### 采集 Slice 信号

- ID: `slice_signals`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/slice_signals.sql`](../sql/rendering_pipeline_detection/slice_signals.sql)

```yaml
id: slice_signals
type: atomic
display:
  level: detail
  title: Slice 特征检测
save_as: slice_signals
```
### 计算管线得分

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
### 确定主管线

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
### 生成 Pin 指令

- ID: `pin_instructions`
- Type: `atomic`
- SQL: [`../sql/rendering_pipeline_detection/pin_instructions.sql`](../sql/rendering_pipeline_detection/pin_instructions.sql)

```yaml
id: pin_instructions
type: atomic
display:
  level: detail
  title: Track 固定建议
save_as: pin_instructions
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
## Output and evidence contract

```yaml
format: structured
fields:
- name: pipeline_result
  description: 主管线识别结果
- name: subvariants
  description: 子变体信息
- name: pin_instructions
  description: Track 固定建议
- name: trace_requirements
  description: 采集完整性检查
- name: pipeline_scores
  description: 各管线类型得分 (调试用)
- name: active_rendering_processes
  description: 活跃渲染进程列表 (用于智能 Pin)
```
