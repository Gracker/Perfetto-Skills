GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/webview_drawfunctor_jank_chain.skill.yaml
Source SHA-256: d0794e39385b8e2f575eebff3c0229ba4ca0b468c5845b371ac3187f521f2c7a
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# WebView GL Functor 卡顿链路

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: webview_drawfunctor_jank_chain
version: '1.0'
type: composite
category: rendering
tier: A
```

## Metadata

```yaml
display_name: WebView GL Functor 卡顿链路
description: 关联 WebView/Chromium JS 长任务、GL Functor 绘制和宿主帧掉帧窗口
icon: web
tags:
- webview
- chromium
- drawfunctor
- v8
- frame
- jank
- composite
```

## Triggers

```yaml
keywords:
  zh:
  - WebView GL Functor
  - DrawGL
  - DrawFunctor
  - Chromium 卡顿
  - JS 到帧
  en:
  - webview gl functor
  - DrawGL
  - DrawFunctor
  - chromium jank
  - javascript to frame
patterns:
- .*(WebView|Chromium).*(DrawGL|DrawFunctor|GL Functor|卡顿|掉帧).*
- .*(webview|chromium).*(drawgl|drawfunctor|gl functor|jank|frame).*
```

## Prerequisites

```yaml
required_tables:
- actual_frame_timeline_slice
- slice
- thread_track
- thread
- process
modules:
- android.frames.timeline
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

### WebView Functor 信号概览

- ID: `drawfunctor_signal_summary`
- Type: `atomic`
- SQL: [`../sql/webview_drawfunctor_jank_chain/drawfunctor_signal_summary.sql`](../sql/webview_drawfunctor_jank_chain/drawfunctor_signal_summary.sql)

```yaml
id: drawfunctor_signal_summary
type: atomic
display:
  level: summary
  layer: overview
  title: WebView GL Functor / Chromium 信号概览
  columns:
  - name: phase
    label: 阶段
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: slice_count
    label: 次数
    type: number
    format: compact
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
save_as: drawfunctor_signal_summary
```
### Functor/JS 与宿主帧重叠

- ID: `drawfunctor_frame_overlap`
- Type: `atomic`
- SQL: [`../sql/webview_drawfunctor_jank_chain/drawfunctor_frame_overlap.sql`](../sql/webview_drawfunctor_jank_chain/drawfunctor_frame_overlap.sql)

```yaml
id: drawfunctor_frame_overlap
type: atomic
display:
  level: detail
  layer: list
  title: WebView Functor / JS 工作与宿主帧重叠
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
  - name: overlapped_frames
    label: 重叠帧数
    type: number
    format: compact
  - name: janky_frames
    label: 掉帧重叠
    type: number
    format: compact
  - name: max_overlap_ms
    label: 最大重叠
    type: duration
    format: duration_ms
  - name: max_frame_dur_ms
    label: 最大帧耗时
    type: duration
    format: duration_ms
save_as: drawfunctor_frame_overlap
```
### WebView V8 长任务

- ID: `v8_long_tasks`
- Type: `skill`

```yaml
id: v8_long_tasks
type: skill
skill: webview_v8_analysis
params:
  package: ${package|${process_name|}}
  start_ts: ${start_ts}
  end_ts: ${end_ts}
display:
  level: detail
save_as: v8_long_tasks
```
## Output and evidence contract

```yaml
format: structured
```
