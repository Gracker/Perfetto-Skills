GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/touch_to_display_latency.skill.yaml
Source SHA-256: 1eae013ffdaba631ee4959847e00cae0c4786b003c28a3a01975e8592b873da3
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
# 触摸到显示延迟 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: touch_to_display_latency
version: '2.0'
type: atomic
category: input_response
tier: B
```

## Metadata

```yaml
display_name: 触摸到显示延迟 (区间)
description: 基于 android_input_events 的 5 维延迟分解，测量每个输入事件的端到端延迟
icon: touch_app
tags:
- touch
- latency
- display
- follow_finger
- atomic
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
- name: event_type
  type: string
  required: false
  description: 输入事件类型过滤（如 MOTION/KEY）
```

## Query

Run [`../sql/touch_to_display_latency/query.sql`](../sql/touch_to_display_latency/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 触摸到显示延迟
columns:
- name: input_ts
  label: 输入时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
- name: process_name
  label: 进程
  type: string
- name: event_type
  label: 事件类型
  type: string
- name: event_action
  label: 事件动作
  type: string
- name: dispatch_latency_ms
  label: 分发延迟
  type: duration
  format: duration_ms
- name: handling_latency_ms
  label: 处理延迟
  type: duration
  format: duration_ms
- name: ack_latency_ms
  label: ACK 延迟
  type: duration
  format: duration_ms
- name: total_latency_ms
  label: 总延迟
  type: duration
  format: duration_ms
- name: e2e_latency_ms
  label: 端到端延迟
  type: duration
  format: duration_ms
- name: normalized_channel
  label: 窗口
  type: string
- name: is_speculative_frame
  label: 推测帧
  type: boolean
- name: rating
  label: 评级
  type: string
```
