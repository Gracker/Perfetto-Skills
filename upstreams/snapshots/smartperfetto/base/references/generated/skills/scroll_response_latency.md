GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/scroll_response_latency.skill.yaml
Source SHA-256: d89dec74765b5e8b1f68f450ec1579c149e0d6b3db6adb5e0ffe9c04b2799859
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# 滚动响应延迟 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: scroll_response_latency
version: '2.0'
type: atomic
category: input_response
tier: B
```

## Metadata

```yaml
display_name: 滚动响应延迟 (区间)
description: 基于 android_input_events 测量滚动手势从 MOVE dispatch 到首帧开始的候选响应延迟
icon: swipe_right
tags:
- scroll
- response
- latency
- input
- atomic
pipeline_aware: true
pipeline_aware_note: '滑动响应路径不同：标准 input→Choreographer→ViewRoot；

  Flutter texture 模式额外多一层宿主采样；WebView Functor 含 Chromium 路径；

  RN input→main→Bridge/JSI→mqt_js。未来按 pipeline_id 调整响应路径解析。

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
```

## Query

Run [`../sql/scroll_response_latency/query.sql`](../sql/scroll_response_latency/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: key
layer: list
title: 滚动响应延迟
columns:
- name: gesture_ts
  label: 手势时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: process_name
  label: 进程
  type: string
- name: response_latency_ms
  label: 响应延迟
  type: duration
  format: duration_ms
- name: first_frame_dur_ms
  label: 首帧耗时
  type: duration
  format: duration_ms
- name: rating
  label: 评级
  type: string
```
