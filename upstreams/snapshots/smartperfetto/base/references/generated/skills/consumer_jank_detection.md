GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
Source SHA-256: 55465b17c1e74abda8e2e04bb70d0c079459a9f4095de2b56b420ac9721ee0c0
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# Consumer Jank 检测

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: consumer_jank_detection
version: '1.0'
type: atomic
category: rendering
tier: A
```

## Metadata

```yaml
display_name: Consumer Jank 检测
description: 检测 Consumer (SurfaceFlinger) 侧的卡顿
icon: warning
tags:
- jank
- consumer
- surfaceflinger
- atomic
pipeline_aware: true
pipeline_aware_note: '本 skill 已暴露 pipeline_id 可选输入。

  当前实现按 layer_name 过滤通用判断（pipeline-agnostic），未来可按 pipeline_id 切换 SQL：

  - Flutter: 1.ui jank（Animator::BeginFrame 超 budget）vs 1.raster jank（Rasterizer 超 budget）分开计

  - Camera: 多路输出 back-pressure 归因（preview/analysis/record）

  - Video: codec underflow（releaseOutputBuffer pool 耗尽）vs HWC overlay degradation

  - Game: 三线程 lag 归因（GameThread/RenderThread/RHIThread）

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 消费端卡顿
  - present interval
  - SurfaceFlinger
  - 显示端卡顿
  - 帧呈现
  en:
  - consumer jank
  - present interval
  - surfaceflinger
  - display jank
patterns:
- .*(消费端|显示端).*(卡顿|掉帧).*
- .*(consumer|present|display).*jank.*
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
  description: 应用包名
- name: layer_name
  type: string
  required: false
  description: Layer 名称（可选，用于精确匹配）
- name: start_ts
  type: timestamp
  required: false
- name: end_ts
  type: timestamp
  required: false
- name: pipeline_id
  type: string
  required: false
  description: 'Pipeline ID (Phase F: pipeline-aware optional input; 当前实现 pipeline-agnostic, 未来按 pipeline 切换 SQL)'
```

## Ordered execution

### VSync 配置

- ID: `vsync_config`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/vsync_config.sql`](../sql/consumer_jank_detection/vsync_config.sql)

```yaml
id: vsync_config
type: atomic
save_as: vsync_config
```
### 消费端掉帧检测

- ID: `consumer_jank_frames`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/consumer_jank_frames.sql`](../sql/consumer_jank_detection/consumer_jank_frames.sql)

```yaml
id: consumer_jank_frames
type: atomic
display:
  level: detail
  title: 真正的掉帧帧（SF 消费端视角）
  columns:
  - name: frame_id
    label: 帧ID
    type: string
  - name: layer_name
    label: 图层
    type: string
  - name: ts_str
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: ts_sec
    label: 时间(s)
    type: number
  - name: dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
    unit: ms
  - name: token_gap
    label: Token跳跃
    type: number
  - name: vsync_missed
    label: 跳帧数
    type: number
  - name: interval_ms
    label: 间隔
    type: duration
    format: duration_ms
    unit: ms
  - name: app_jank_type
    label: App标记
    type: string
  - name: jank_severity
    label: 严重程度
    type: string
  - name: delay_source
    label: 延迟来源
    type: string
    description: app_late=应用渲染超时, sf_late=SF/显示延迟, buffer_stuffing=缓冲区满
save_as: consumer_jank_frames
```
### 消费端掉帧汇总

- ID: `consumer_jank_summary`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/consumer_jank_summary.sql`](../sql/consumer_jank_detection/consumer_jank_summary.sql)

```yaml
id: consumer_jank_summary
type: atomic
display:
  level: summary
  title: 消费端掉帧统计
  columns:
  - name: total_frames
    label: 总帧数
    type: number
    format: compact
  - name: consumer_jank_frames
    label: 掉帧数
    type: number
    format: compact
  - name: smooth_frames
    label: 流畅帧
    type: number
    format: compact
  - name: consumer_jank_rate
    label: 掉帧率
    type: percentage
    format: percentage
  - name: max_vsync_missed
    label: 最大跳帧
    type: number
  - name: rating
    label: 评级
    type: string
save_as: consumer_jank_summary
```
### 掉帧严重程度分布

- ID: `jank_severity_distribution`
- Type: `atomic`
- SQL: [`../sql/consumer_jank_detection/jank_severity_distribution.sql`](../sql/consumer_jank_detection/jank_severity_distribution.sql)

```yaml
id: jank_severity_distribution
type: atomic
display:
  level: detail
  title: 掉帧严重程度分布
  columns:
  - name: severity
    label: 严重程度
    type: string
  - name: count
    label: 帧数
    type: number
    format: compact
  - name: percentage
    label: 占比
    type: percentage
    format: percentage
save_as: jank_severity_distribution
```
## Output and evidence contract

```yaml
format: structured
fields:
- name: consumer_jank_frames
  description: 真正的掉帧帧列表
- name: consumer_jank_summary
  description: 消费端掉帧统计汇总
- name: jank_severity_distribution
  description: 掉帧严重程度分布
```
