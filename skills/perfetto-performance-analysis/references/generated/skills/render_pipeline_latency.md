GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/render_pipeline_latency.skill.yaml
Source SHA-256: 485299ac47ece0112e0d06665583b421d13314d59be5ff19a7286223dab81d4b
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# 渲染流水线时延

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: render_pipeline_latency
version: '1.0'
type: atomic
category: rendering
tier: B
```

## Metadata

```yaml
display_name: 渲染流水线时延
description: 分解帧渲染全链路各阶段耗时
icon: timeline
tags:
- render
- pipeline
- latency
- atomic
pipeline_aware: true
pipeline_aware_note: '端到端延迟的"端"在不同 pipeline 不同：

  标准 HWUI input→display；Flutter 1.ui begin→1.raster done→present；

  Game 引擎 swapBuffers→present；Camera HAL processCaptureRequest→preview present。

  '
```

## Triggers

```yaml
keywords:
  zh:
  - 渲染流水线
  - 渲染时延
  - 端到端延迟
  - RenderThread
  - 主线程
  en:
  - render pipeline latency
  - rendering latency
  - end-to-end frame latency
patterns:
- .*(渲染|pipeline).*(时延|延迟|耗时).*
- .*render.*pipeline.*latency.*
```

## Prerequisites

```yaml
modules:
- android.frames.timeline
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: true
  description: 帧开始时间戳(ns)
- name: end_ts
  type: timestamp
  required: true
  description: 帧结束时间戳(ns)
- name: main_start_ts
  type: timestamp
  required: false
  description: 主线程开始时间戳(ns)
- name: main_end_ts
  type: timestamp
  required: false
  description: 主线程结束时间戳(ns)
- name: render_start_ts
  type: timestamp
  required: false
  description: RenderThread 开始时间戳(ns)
- name: render_end_ts
  type: timestamp
  required: false
  description: RenderThread 结束时间戳(ns)
```

## Query

Run [`../sql/render_pipeline_latency/query.sql`](../sql/render_pipeline_latency/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: deep
title: 渲染流水线
columns:
- name: stage
  label: 阶段
  type: string
- name: dur_ms
  label: 耗时
  type: duration
  format: duration_ms
- name: pct
  label: 占比
  type: percentage
  format: percentage
```
