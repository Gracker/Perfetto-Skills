GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/webview_v8_analysis.skill.yaml
Source SHA-256: 2049705d85775c01fb32fc6391b66c22d69cd8ec313a1543111b4c0fbb42ad9f
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# WebView V8 性能分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: webview_v8_analysis
version: '1.0'
type: atomic
category: rendering
tier: A
```

## Metadata

```yaml
display_name: WebView V8 性能分析
description: 分析 WebView V8 引擎性能：GC 事件、脚本编译、执行时间
icon: javascript
tags:
- webview
- v8
- javascript
- gc
- compilation
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - WebView
  - V8
  - JavaScript
  - JS 长任务
  - Chromium
  - 网页卡顿
  en:
  - webview
  - v8
  - javascript
  - js long task
  - chromium
patterns:
- .*(WebView|V8|JavaScript|JS).*(卡顿|长任务|GC).*
- .*(webview|v8|javascript|chromium).*(jank|gc|long task).*
```

## Prerequisites

```yaml
required_tables:
- slice
modules:
- android.frames.timeline
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
```

## Ordered execution

### V8 GC 事件

- ID: `v8_gc_events`
- Type: `atomic`
- SQL: [`../sql/webview_v8_analysis/v8_gc_events.sql`](../sql/webview_v8_analysis/v8_gc_events.sql)

```yaml
id: v8_gc_events
type: atomic
display:
  level: summary
  layer: overview
  title: V8 GC 事件概览
  columns:
  - name: gc_type
    label: GC 类型
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: count
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
  - name: max_dur_ms
    label: 最大耗时
    type: duration
    format: duration_ms
  - name: rating
    label: 评级
    type: string
save_as: v8_gc_events
```
### V8 脚本执行

- ID: `v8_script_execution`
- Type: `atomic`
- SQL: [`../sql/webview_v8_analysis/v8_script_execution.sql`](../sql/webview_v8_analysis/v8_script_execution.sql)

```yaml
id: v8_script_execution
type: atomic
display:
  level: detail
  layer: list
  title: V8 JavaScript 执行时间
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: slice_name
    label: Slice 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: dur_ns
    label: 耗时(ns)
    type: duration
    unit: ns
    hidden: true
  - name: severity
    label: 严重程度
    type: string
save_as: v8_script_execution
```
### V8 编译开销

- ID: `v8_compilation`
- Type: `atomic`
- SQL: [`../sql/webview_v8_analysis/v8_compilation.sql`](../sql/webview_v8_analysis/v8_compilation.sql)

```yaml
id: v8_compilation
type: atomic
display:
  level: detail
  layer: list
  title: V8 脚本编译开销
  columns:
  - name: ts
    label: 时间
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: slice_name
    label: Slice 名称
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: dur_ms
    label: 耗时
    type: duration
    format: duration_ms
  - name: dur_ns
    label: 耗时(ns)
    type: duration
    unit: ns
    hidden: true
save_as: v8_compilation
```
### V8 GC 帧影响

- ID: `v8_frame_impact`
- Type: `atomic`
- SQL: [`../sql/webview_v8_analysis/v8_frame_impact.sql`](../sql/webview_v8_analysis/v8_frame_impact.sql)

```yaml
id: v8_frame_impact
type: atomic
optional: true
display:
  level: detail
  layer: deep
  title: V8 GC 与帧渲染重叠
  columns:
  - name: gc_ts
    label: GC 时间
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: gc_name
    label: GC 事件
    type: string
  - name: gc_dur_ms
    label: GC 耗时
    type: duration
    format: duration_ms
  - name: frame_dur_ms
    label: 帧耗时
    type: duration
    format: duration_ms
  - name: jank_type
    label: 卡顿类型
    type: string
  - name: overlap_ms
    label: 重叠时间
    type: duration
    format: duration_ms
save_as: v8_frame_impact
```
## Output and evidence contract

```yaml
format: structured
```
