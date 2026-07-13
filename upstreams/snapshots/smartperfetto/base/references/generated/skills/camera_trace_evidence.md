GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/camera_trace_evidence.skill.yaml
Source SHA-256: d2f99680715212f30bafe86e1323d04cb469e5582ac89cad1e8c7b48f92e9c2e
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31
# Camera Trace 证据

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: camera_trace_evidence
version: '1.0'
type: composite
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Camera Trace 证据
description: 枚举 Camera 相关 identity、slice、Binder、系统上下文、DMA-BUF/legacy ION 与可选 Pixel stage 证据
icon: photo_camera
tags:
- camera
- rendering
- evidence
- binder
- dmabuf
- ion
- pixel
```

## Triggers

```yaml
keywords:
  zh:
  - Camera
  - 相机
  - 打开相机
  - 相机内存
  en:
  - camera
  - camera open
  - camera memory
patterns:
- .*(camera|Camera|相机).*(open|preview|capture|打开|预览|拍照|DMA|dmabuf).*
- .*(open|preview|capture|打开|预览|拍照).*(camera|Camera|相机).*
```

## Prerequisites

```yaml
required_tables:
- slice
- thread
- process
modules:
- slices.with_context
- android.binder
- android.frames.timeline
- android.memory.dmabuf
- linux.cpu.frequency
- pixel.camera
```

## Inputs

```yaml
- name: start_ts
  type: timestamp
  required: false
  description: 分析起始时间戳(ns)，默认 trace_start()
- name: end_ts
  type: timestamp
  required: false
  description: 分析结束时间戳(ns)，默认 trace_end()
- name: max_rows
  type: integer
  required: false
  default: 20
  description: 每个明细步骤最大返回行数，限制为 1-100
```

## Ordered execution

### Camera 证据覆盖

- ID: `evidence_coverage`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/evidence_coverage.sql`](../sql/camera_trace_evidence/evidence_coverage.sql)

```yaml
id: evidence_coverage
type: atomic
display:
  layer: overview
  level: summary
  title: Camera 证据覆盖
  columns:
  - name: evidence_family
    label: 证据族
    type: string
  - name: status
    label: 状态
    type: string
  - name: row_count
    label: 行数
    type: number
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: evidence_coverage
synthesize:
  role: overview
  fields:
  - key: evidence_family
    label: 证据族
  - key: status
    label: 可用性
  - key: row_count
    label: 行数
  - key: limitation
    label: 限制
```
### Camera 进程/线程候选

- ID: `camera_process_candidates`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_process_candidates.sql`](../sql/camera_trace_evidence/camera_process_candidates.sql)

```yaml
id: camera_process_candidates
type: atomic
display:
  layer: list
  level: detail
  title: Camera identity 候选
  columns:
  - name: identity_kind
    label: 类型
    type: string
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: pid
    label: PID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: tid
    label: TID
    type: number
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: camera_process_candidates
synthesize:
  role: list
  fields:
  - key: identity_kind
    label: Identity 类型
  - key: process_name
    label: 进程
  - key: thread_name
    label: 线程
  - key: source
    label: 来源
```
### Camera Slice 候选

- ID: `camera_slice_candidates`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_slice_candidates.sql`](../sql/camera_trace_evidence/camera_slice_candidates.sql)

```yaml
id: camera_slice_candidates
type: atomic
display:
  layer: list
  level: detail
  title: Camera slice 候选
  columns:
  - name: ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 时长
    type: duration
    unit: ns
    format: duration_ms
  - name: slice_name
    label: Slice
    type: string
    format: truncate
  - name: process_name
    label: 进程
    type: string
  - name: thread_name
    label: 线程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: utid
    label: UTID
    type: number
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: camera_slice_candidates
synthesize:
  role: list
  fields:
  - key: slice_name
    label: Slice 候选
  - key: process_name
    label: 进程
  - key: thread_name
    label: 线程
  - key: source
    label: 来源
```
### Camera Binder 事务

- ID: `camera_binder_summary`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_binder_summary.sql`](../sql/camera_trace_evidence/camera_binder_summary.sql)

```yaml
id: camera_binder_summary
type: atomic
display:
  layer: list
  level: detail
  title: Camera 相关 Binder 事务
  columns:
  - name: ts
    label: 开始
    type: timestamp
    unit: ns
    clickAction: navigate_range
    durationColumn: dur_ns
  - name: dur_ns
    label: 耗时
    type: duration
    unit: ns
    format: duration_ms
  - name: aidl_name
    label: AIDL
    type: string
    format: truncate
  - name: client_process
    label: Client 进程
    type: string
  - name: client_thread
    label: Client 线程
    type: string
  - name: server_process
    label: Server 进程
    type: string
  - name: server_thread
    label: Server 线程
    type: string
  - name: client_upid
    label: Client UPID
    type: number
  - name: client_utid
    label: Client UTID
    type: number
  - name: server_upid
    label: Server UPID
    type: number
  - name: server_utid
    label: Server UTID
    type: number
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: camera_binder_summary
synthesize:
  role: list
  fields:
  - key: aidl_name
    label: Binder 接口
  - key: client_process
    label: Client
  - key: server_process
    label: Server
  - key: source
    label: 来源
```
### Camera DMA-BUF/legacy ION window evidence

- ID: `camera_dmabuf_summary`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_dmabuf_summary.sql`](../sql/camera_trace_evidence/camera_dmabuf_summary.sql)

```yaml
id: camera_dmabuf_summary
type: atomic
display:
  layer: list
  level: detail
  title: Camera DMA-BUF/legacy ION window evidence
  columns:
  - name: process_name
    label: 进程
    type: string
  - name: upid
    label: UPID
    type: number
  - name: pid
    label: PID
    type: number
  - name: memory_source
    label: 内存来源
    type: string
  - name: allocation_count
    label: 分配次数
    type: number
  - name: allocation_bytes
    label: 分配量
    type: bytes
  - name: release_bytes
    label: 释放量
    type: bytes
  - name: observed_net_delta_bytes
    label: 窗口内观测净变化
    type: bytes
  - name: peak_event_bytes
    label: 最大单事件
    type: bytes
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: camera_dmabuf_summary
synthesize:
  role: list
  fields:
  - key: process_name
    label: 进程
  - key: memory_source
    label: 内存来源
  - key: allocation_bytes
    label: 窗口内分配量
  - key: release_bytes
    label: 窗口内释放量
  - key: observed_net_delta_bytes
    label: 窗口内观测净变化
  - key: limitation
    label: 限制
```
### Pixel Camera Stage 摘要

- ID: `pixel_camera_stage_summary`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/pixel_camera_stage_summary.sql`](../sql/camera_trace_evidence/pixel_camera_stage_summary.sql)

```yaml
id: pixel_camera_stage_summary
type: atomic
display:
  layer: list
  level: detail
  title: 可选 Pixel Camera stage
  columns:
  - name: cam_id
    label: Camera ID
    type: number
  - name: node
    label: Node
    type: string
  - name: port_group
    label: Port group
    type: string
  - name: frame_count
    label: 帧数
    type: number
  - name: avg_duration_ns
    label: 平均时长
    type: duration
    unit: ns
    format: duration_ms
  - name: max_duration_ns
    label: 最大时长
    type: duration
    unit: ns
    format: duration_ms
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 限制
    type: string
    format: truncate
save_as: pixel_camera_stage_summary
synthesize:
  role: list
  fields:
  - key: cam_id
    label: Camera ID
  - key: node
    label: Node
  - key: port_group
    label: Port group
  - key: frame_count
    label: 帧数
  - key: source
    label: 来源
```
## Output and evidence contract

```yaml
format: structured
```
