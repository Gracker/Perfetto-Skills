GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/gl_standalone_swap_jank.skill.yaml
Source SHA-256: 099d717e80e4a568d18a565c1bec7714b24451ed809a8c35527cdff3c29eabc9
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# 独立 GL/Vulkan Swap 卡顿

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: gl_standalone_swap_jank
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 独立 GL/Vulkan Swap 卡顿
description: 检测 eglSwapBuffers/vkQueuePresent/queueBuffer 间隔异常，定位 GLSurfaceView/NativeActivity 自渲染掉帧
icon: developer_board
tags:
- opengl
- vulkan
- swap_buffers
- glsurfaceview
- native_activity
- jank
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - GLSurfaceView
  - NativeActivity
  - eglSwapBuffers
  - vkQueuePresent
  - OpenGL 卡顿
  - Vulkan 卡顿
  en:
  - glsurfaceview
  - nativeactivity
  - eglswapbuffers
  - vkqueuepresent
  - opengl jank
  - vulkan jank
patterns:
- .*(GLSurfaceView|NativeActivity|OpenGL|Vulkan).*(卡顿|掉帧|swap).*
- .*(glsurfaceview|nativeactivity|opengl|vulkan).*(jank|swap|present).*
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
```

## Ordered execution

### Swap 间隔汇总

- ID: `swap_interval_summary`
- Type: `atomic`
- SQL: [`../sql/gl_standalone_swap_jank/swap_interval_summary.sql`](../sql/gl_standalone_swap_jank/swap_interval_summary.sql)

```yaml
id: swap_interval_summary
type: atomic
display:
  level: summary
  layer: overview
  title: GL/Vulkan Swap 间隔汇总
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: swap_count
    label: Swap次数
    type: number
    format: compact
  - name: target_interval_ms
    label: 目标间隔
    type: duration
    format: duration_ms
  - name: avg_interval_ms
    label: 平均间隔
    type: duration
    format: duration_ms
  - name: p95_interval_ms
    label: P95间隔
    type: duration
    format: duration_ms
  - name: max_interval_ms
    label: 最大间隔
    type: duration
    format: duration_ms
  - name: missed_like_count
    label: 疑似掉帧
    type: number
    format: compact
  - name: rating
    label: 评级
    type: string
save_as: swap_interval_summary
```
### 慢 Swap 事件

- ID: `slow_swap_events`
- Type: `atomic`
- SQL: [`../sql/gl_standalone_swap_jank/slow_swap_events.sql`](../sql/gl_standalone_swap_jank/slow_swap_events.sql)

```yaml
id: slow_swap_events
type: atomic
display:
  level: detail
  layer: list
  title: 慢 GL/Vulkan Swap 间隔
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: interval_ms
    label: 距离上次Swap
    type: duration
    format: duration_ms
  - name: swap_dur_ms
    label: Swap调用耗时
    type: duration
    format: duration_ms
  - name: slice_name
    label: Slice
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: process_name
    label: 进程
    type: string
save_as: slow_swap_events
```
## Output and evidence contract

```yaml
format: structured
```
