GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 逐帧 Input-to-Display 延迟

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: input_to_frame_latency
version: '2.0'
type: atomic
category: input_response
tier: A
```

## Metadata

```yaml
display_name: 逐帧 Input-to-Display 延迟
description: 基于 android_input_events 测量每个 MotionEvent 到对应帧 present 的延迟，用于跟手度分析
icon: swipe_vertical
tags:
- touch_tracking
- follow_finger
- input
- latency
- per_frame
- atomic
pipeline_aware: true
pipeline_aware_note: 'Input 触达"应用"的路径在不同 pipeline 下不同（S14 React Native / S10 Flutter / S09 WebView）：

  - 标准 HWUI: input → main thread → Choreographer.doFrame

  - Flutter: input → platform thread → 1.ui thread Animator::BeginFrame

  - RN Old Arch: input → main → Bridge → mqt_js → Bridge → main → 原生 View

  - RN New Arch: input → main → JSI → mqt_js → Fabric → main

  未来按 pipeline_id 切换 input 路径与帧绑定 SQL。

  '
```

## Prerequisites

```yaml
modules:
- android.input
```

## Inputs

```yaml
- name: package
  type: string
  required: false
  description: 目标进程名（支持 GLOB）
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)
- name: event_action_filter
  type: string
  required: false
  description: 事件动作过滤（默认 MOVE）
- name: pipeline_id
  type: string
  required: false
  description: 'Pipeline ID (Phase F: pipeline-aware optional input)'
```

## Ordered execution

### VSync 周期检测

- ID: `vsync_period`
- Type: `atomic`
- SQL: [`../sql/input_to_frame_latency/vsync_period.sql`](../sql/input_to_frame_latency/vsync_period.sql)

```yaml
id: vsync_period
type: atomic
display:
  level: summary
  layer: overview
  title: VSync 配置
  columns:
  - name: vsync_period_ns
    label: VSync 周期(ns)
    type: number
  - name: refresh_rate_hz
    label: 刷新率(Hz)
    type: number
```
### 输入采样率检测

- ID: `input_sampling_rate`
- Type: `atomic`
- SQL: [`../sql/input_to_frame_latency/input_sampling_rate.sql`](../sql/input_to_frame_latency/input_sampling_rate.sql)

```yaml
id: input_sampling_rate
type: atomic
display:
  level: summary
  layer: overview
  title: 触控采样率
  columns:
  - name: median_interval_ms
    label: 中位间隔(ms)
    type: number
  - name: sampling_rate_hz
    label: 采样率(Hz)
    type: number
  - name: total_events
    label: 事件总数
    type: number
```
### 逐帧延迟

- ID: `per_frame_latency`
- Type: `atomic`
- SQL: [`../sql/input_to_frame_latency/per_frame_latency.sql`](../sql/input_to_frame_latency/per_frame_latency.sql)

```yaml
id: per_frame_latency
type: atomic
display:
  level: detail
  layer: list
  title: 逐帧 Input-to-Display 延迟
  columns:
  - name: input_ts
    label: 输入时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: process_name
    label: 进程
    type: string
  - name: event_action
    label: 事件
    type: string
  - name: input_to_display_ms
    label: Input→Display(ms)
    type: duration
    format: duration_ms
  - name: dispatch_latency_ms
    label: 分发延迟(ms)
    type: duration
    format: duration_ms
  - name: handling_ms
    label: 处理延迟(ms)
    type: duration
    format: duration_ms
  - name: ack_ms
    label: ACK延迟(ms)
    type: duration
    format: duration_ms
  - name: frame_dur_ms
    label: 帧耗时(ms)
    type: duration
    format: duration_ms
  - name: frame_to_present_ms
    label: Frame→Present(ms)
    type: duration
    format: duration_ms
  - name: is_speculative
    label: 推测帧
    type: boolean
  - name: rating
    label: 评级
    type: string
```
### 延迟统计

- ID: `latency_statistics`
- Type: `atomic`
- SQL: [`../sql/input_to_frame_latency/latency_statistics.sql`](../sql/input_to_frame_latency/latency_statistics.sql)

```yaml
id: latency_statistics
type: atomic
display:
  level: summary
  layer: overview
  title: Input-to-Display 延迟统计
  columns:
  - name: metric
    label: 指标
    type: string
  - name: value_ms
    label: 值(ms)
    type: number
```
### 延迟飙升检测

- ID: `latency_spikes`
- Type: `atomic`
- SQL: [`../sql/input_to_frame_latency/latency_spikes.sql`](../sql/input_to_frame_latency/latency_spikes.sql)

```yaml
id: latency_spikes
type: atomic
display:
  level: detail
  layer: list
  title: 延迟飙升点
  columns:
  - name: input_ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: latency_ms
    label: 延迟(ms)
    type: duration
    format: duration_ms
  - name: prev_latency_ms
    label: 前帧延迟(ms)
    type: duration
    format: duration_ms
  - name: spike_ratio
    label: 飙升倍数
    type: number
  - name: is_speculative
    label: 推测帧
    type: boolean
```
## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 逐帧 Input-to-Display 延迟
columns:
- name: input_ts
  label: 输入时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: process_name
  label: 进程
  type: string
- name: event_action
  label: 事件
  type: string
- name: input_to_display_ms
  label: Input→Display
  type: duration
  format: duration_ms
- name: dispatch_latency_ms
  label: 分发延迟
  type: duration
  format: duration_ms
- name: handling_ms
  label: 处理延迟
  type: duration
  format: duration_ms
- name: frame_dur_ms
  label: 帧耗时
  type: duration
  format: duration_ms
- name: frame_to_present_ms
  label: Frame→Present
  type: duration
  format: duration_ms
- name: is_speculative
  label: 推测帧
  type: boolean
- name: rating
  label: 评级
  type: string
```
