GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/input_events_in_range.skill.yaml
Source SHA-256: 55d6681383a486d2bb4ba6b2229acb5445d935eb1b8e27148503595a16ff137b
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 输入事件列表 (区间)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: input_events_in_range
version: '2.0'
type: atomic
category: input_response
tier: B
```

## Metadata

```yaml
display_name: 输入事件列表 (区间)
description: 提取区间内已完成 ACK 的输入事件（触摸、按键），包含 dispatch/handling/ACK 和可用的 frame 关联延迟
icon: touch_app
tags:
- input
- events
- touch
- key
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
  description: 事件类型过滤（MOTION/KEY）
- name: event_action
  type: string
  required: false
  description: 事件动作过滤（DOWN/MOVE/UP）
```

## Query

Run [`../sql/input_events_in_range/query.sql`](../sql/input_events_in_range/query.sql) with the declared inputs.

## Output and evidence contract

```yaml
format: structured
```

## Display metadata

```yaml
level: detail
layer: list
title: 输入事件列表
columns:
- name: event_ts
  label: 事件时间
  type: timestamp
  unit: ns
  clickAction: navigate_timeline
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
  label: 总延迟(ACK)
  type: duration
  format: duration_ms
- name: e2e_latency_ms
  label: Input→Frame 延迟
  type: duration
  format: duration_ms
- name: process_name
  label: 目标进程
  type: string
- name: normalized_channel
  label: 窗口
  type: string
- name: dispatch_status
  label: 状态
  type: string
```
