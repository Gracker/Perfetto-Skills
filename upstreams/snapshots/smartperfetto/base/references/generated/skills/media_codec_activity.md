GENERATED FILE - DO NOT EDIT.
Source: backend/skills/atomic/media_codec_activity.skill.yaml
Source SHA-256: f9785c4a5b759aab3f1efe3c1d4faede153488cd9f89592428318f926cda0bbb
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d
# 媒体 Codec 活动分析

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: media_codec_activity
version: '1.0'
type: atomic
category: media
tier: B
```

## Metadata

```yaml
display_name: 媒体 Codec 活动分析
description: 检测 MediaCodec/Codec2/OMX/CCodec 相关线程和 buffer API 切片，定位慢解码、queue/dequeue 和 releaseOutputBuffer 问题
icon: movie
tags:
- media
- codec
- decoder
- video
- audio
- buffer
- atomic
```

## Triggers

```yaml
keywords:
  zh:
  - MediaCodec
  - Codec2
  - OMX
  - 解码卡顿
  - 视频卡顿
  - 音视频
  - releaseOutputBuffer
  en:
  - mediacodec
  - codec2
  - omx
  - decoder jank
  - video stutter
  - releaseOutputBuffer
patterns:
- .*(MediaCodec|Codec2|OMX|CCodec).*(卡顿|慢|解码|buffer).*
- .*(mediacodec|codec2|omx|ccodec).*(jank|slow|decode|buffer).*
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
- name: slow_threshold_ms
  type: number
  required: false
  description: 慢 codec 事件阈值(ms)，默认 8
```

## Ordered execution

### Codec 活动汇总

- ID: `codec_activity_summary`
- Type: `atomic`
- SQL: [`../sql/media_codec_activity/codec_activity_summary.sql`](../sql/media_codec_activity/codec_activity_summary.sql)

```yaml
id: codec_activity_summary
type: atomic
display:
  level: summary
  layer: overview
  title: Media Codec 活动汇总
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
  - name: total_dur_ms
    label: 总耗时
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
save_as: codec_activity_summary
```
### 慢 Codec 事件

- ID: `slow_codec_events`
- Type: `atomic`
- SQL: [`../sql/media_codec_activity/slow_codec_events.sql`](../sql/media_codec_activity/slow_codec_events.sql)

```yaml
id: slow_codec_events
type: atomic
display:
  level: detail
  layer: list
  title: 慢 Media Codec 事件
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
save_as: slow_codec_events
```
## Output and evidence contract

```yaml
format: structured
```
