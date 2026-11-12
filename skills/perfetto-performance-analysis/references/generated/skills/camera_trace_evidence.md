GENERATED FILE - DO NOT EDIT.
Source: backend/skills/composite/camera_trace_evidence.skill.yaml
Source SHA-256: 51f50653a5676ed9b3c272fc9c6fc7f51b670240aaf0b404b6b7fea9bdb6a994
# Camera Trace 证据

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: camera_trace_evidence
version: '1.1'
type: composite
category: rendering
tier: B
```

## Metadata

```yaml
display_name: Camera Trace 证据
description: Camera/preview 的独立 callback 节奏、SF layer/DisplayFrame 呈现端关联、Binder wall/Running 与内存证据；不测 app arrival→present 时延
icon: photo_camera
tags:
- camera
- media
- preview
- rendering
- frame_cadence
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

### FrameTimeline 人口（DisplayFrame / SurfaceFrame 分开）

- ID: `camera_frame_population`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_frame_population.sql`](../sql/camera_trace_evidence/camera_frame_population.sql)

```yaml
id: camera_frame_population
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: overview
  level: summary
  title: FrameTimeline 人口（DisplayFrame / SurfaceFrame 分开）
  columns:
  - name: frame_kind
    label: 帧类型
    type: string
  - name: upid
    label: UPID
    type: number
  - name: process_name
    label: 进程
    type: string
  - name: layer_name
    label: Surface layer（DisplayFrame 为空）
    type: string
  - name: frame_count
    label: 原始条目数
    type: number
  - name: dropped_frames
    label: Dropped 条目数
    type: number
  - name: incomplete_frames
    label: 未完成条目数
    type: number
  - name: window_excluded_endpoints
    label: 完成但呈现端在窗外的条目数
    type: number
  - name: prediction_error_frames
    label: Prediction Error 条目数
    type: number
  - name: scope
    label: 范围
    type: string
  - name: limitation
    label: 边界
    type: string
sql_fragments:
- fragments/camera_frame_observations.sql
save_as: camera_frame_population
synthesize:
  role: overview
  fields:
  - key: frame_kind
    label: 帧类型
  - key: upid
    label: UPID
  - key: process_name
    label: 进程
  - key: layer_name
    label: Surface layer（DisplayFrame 为空）
  - key: frame_count
    label: 原始条目数
  - key: dropped_frames
    label: Dropped 条目数
  - key: incomplete_frames
    label: 未完成条目数
  - key: window_excluded_endpoints
    label: 完成但呈现端在窗外的条目数
  - key: prediction_error_frames
    label: Prediction Error 条目数
```
### App buffer callback 观测节奏（跨线程合并）

- ID: `camera_callback_cadence`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_callback_cadence.sql`](../sql/camera_trace_evidence/camera_callback_cadence.sql)

```yaml
id: camera_callback_cadence
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: overview
  level: summary
  title: App buffer callback 观测节奏（跨线程合并）
  columns:
  - name: source_upid
    label: 观测进程 UPID
    type: number
  - name: source_process
    label: 观测进程
    type: string
  - name: source_surface
    label: 原始 surface 标识
    type: string
  - name: callback_count
    label: Callback 数
    type: number
  - name: callback_threads
    label: Callback 线程数
    type: number
  - name: observed_intervals
    label: 观测间隔数
    type: number
  - name: avg_interval_ns
    label: 平均到达间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: p95_interval_ns
    label: P95到达间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: max_interval_ns
    label: 最大到达间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: observed_callback_fps
    label: 观测到达 FPS
    type: number
  - name: configured_target_status
    label: 配置目标状态
    type: string
  - name: scope
    label: 范围
    type: string
  - name: limitation
    label: 边界
    type: string
sql_fragments:
- fragments/camera_frame_observations.sql
save_as: camera_callback_cadence
synthesize:
  role: overview
  fields:
  - key: source_upid
    label: 观测进程 UPID
  - key: source_process
    label: 观测进程
  - key: source_surface
    label: 原始 surface 标识
  - key: callback_count
    label: Callback 数
  - key: callback_threads
    label: Callback 线程数
  - key: observed_intervals
    label: 观测间隔数
  - key: avg_interval_ns
    label: 平均到达间隔
  - key: p95_interval_ns
    label: P95到达间隔
```
### SF DisplayFrame 呈现端间隔（SF 上下文）

- ID: `camera_display_cadence`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_display_cadence.sql`](../sql/camera_trace_evidence/camera_display_cadence.sql)

```yaml
id: camera_display_cadence
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: overview
  level: summary
  title: SF DisplayFrame 呈现端间隔（SF 上下文）
  columns:
  - name: upid
    label: SF UPID
    type: number
  - name: process_name
    label: SF 进程
    type: string
  - name: presented_display_frames
    label: 完成呈现的 DisplayFrame 数
    type: number
  - name: observed_intervals
    label: 呈现端间隔数
    type: number
  - name: avg_present_interval_ns
    label: 平均呈现端间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: p50_present_interval_ns
    label: P50呈现端间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: p95_present_interval_ns
    label: P95呈现端间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: max_present_interval_ns
    label: 最大呈现端间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: scope
    label: 范围
    type: string
  - name: source
    label: 来源
    type: string
  - name: limitation
    label: 边界
    type: string
sql_fragments:
- fragments/camera_frame_observations.sql
save_as: camera_display_cadence
synthesize:
  role: overview
  fields:
  - key: upid
    label: SF UPID
  - key: process_name
    label: SF 进程
  - key: presented_display_frames
    label: 完成呈现的 DisplayFrame 数
  - key: observed_intervals
    label: 呈现端间隔数
  - key: avg_present_interval_ns
    label: 平均呈现端间隔
  - key: p50_present_interval_ns
    label: P50呈现端间隔
  - key: p95_present_interval_ns
    label: P95呈现端间隔
  - key: max_present_interval_ns
    label: 最大呈现端间隔
```
### 同 surface marker 的呈现节奏与关联覆盖

- ID: `camera_surface_cadence`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_surface_cadence.sql`](../sql/camera_trace_evidence/camera_surface_cadence.sql)

```yaml
id: camera_surface_cadence
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: overview
  level: summary
  title: 同 surface marker 的呈现节奏与关联覆盖
  columns:
  - name: sf_upid
    label: SF UPID
    type: number
  - name: bindable_surface
    label: Surface marker
    type: string
  - name: observed_buffer_keys
    label: 观测 buffer 键数
    type: number
  - name: presented_buffers
    label: 关联到呈现端的 buffer 数
    type: number
  - name: unavailable_bindings
    label: 缺失或歧义关联数
    type: number
  - name: observed_intervals
    label: 同 surface 呈现间隔数
    type: number
  - name: p95_present_interval_ns
    label: P95同 surface 呈现间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: max_present_interval_ns
    label: 最大同 surface 呈现间隔
    type: duration
    unit: ns
    format: duration_ms
  - name: arrival_binding_status
    label: App 到达关联状态
    type: string
  - name: scope
    label: 范围
    type: string
  - name: limitation
    label: 边界
    type: string
sql_fragments:
- fragments/camera_frame_observations.sql
save_as: camera_surface_cadence
synthesize:
  role: overview
  fields:
  - key: sf_upid
    label: SF UPID
  - key: bindable_surface
    label: Surface marker
  - key: observed_buffer_keys
    label: 观测 buffer 键数
  - key: presented_buffers
    label: 关联到呈现端的 buffer 数
  - key: unavailable_bindings
    label: 缺失或歧义关联数
  - key: observed_intervals
    label: 同 surface 呈现间隔数
  - key: p95_present_interval_ns
    label: P95同 surface 呈现间隔
  - key: arrival_binding_status
    label: App 到达关联状态
```
### SF buffer latch → commit → DisplayFrame 明细

- ID: `camera_buffer_delivery`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_buffer_delivery.sql`](../sql/camera_trace_evidence/camera_buffer_delivery.sql)

```yaml
id: camera_buffer_delivery
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: list
  level: detail
  title: SF buffer latch → commit → DisplayFrame 明细
  columns:
  - name: sf_upid
    label: SF UPID
    type: number
  - name: bindable_surface
    label: 完整 SF layer marker
    type: string
  - name: buffer_number
    label: SF Buffer 编号
    type: number
  - name: latch_id
    label: Latch slice ID
    type: number
  - name: commit_id
    label: Commit slice ID
    type: number
  - name: display_token
    label: Display token
    type: number
  - name: display_id
    label: DisplayFrame slice ID
    type: number
  - name: latch_ts
    label: Latch
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: display_present_ts
    label: DisplayFrame 呈现端
    type: timestamp
    unit: ns
    clickAction: navigate_timeline
  - name: binding_status
    label: SF 关联状态
    type: string
  - name: arrival_binding_status
    label: App 到达关联状态
    type: string
  - name: limitation
    label: 边界
    type: string
sql_fragments:
- fragments/camera_frame_observations.sql
save_as: camera_buffer_delivery
synthesize:
  role: list
  fields:
  - key: sf_upid
    label: SF UPID
  - key: bindable_surface
    label: 完整 SF layer marker
  - key: buffer_number
    label: SF Buffer 编号
  - key: latch_id
    label: Latch slice ID
  - key: commit_id
    label: Commit slice ID
  - key: display_token
    label: Display token
  - key: display_present_ts
    label: DisplayFrame 呈现端
  - key: arrival_binding_status
    label: App 到达关联状态
```
### Camera Binder wall / 线程 Running（不测余量）

- ID: `camera_binder_execution`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/camera_binder_execution.sql`](../sql/camera_trace_evidence/camera_binder_execution.sql)

```yaml
id: camera_binder_execution
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
display:
  layer: overview
  level: summary
  title: Camera Binder wall / 线程 Running（不测余量）
  columns:
  - name: client_upid
    label: Client UPID
    type: number
  - name: server_upid
    label: Server UPID
    type: number
  - name: client_process
    label: Client 进程
    type: string
  - name: server_process
    label: Server 进程
    type: string
  - name: transactions
    label: 完整同步事务数
    type: number
  - name: avg_client_wall_ns
    label: Client 平均 wall
    type: duration
    unit: ns
    format: duration_ms
  - name: avg_server_wall_ns
    label: Server 平均 wall
    type: duration
    unit: ns
    format: duration_ms
  - name: server_state_observed_txns
    label: 有 server 线程状态的事务数
    type: number
  - name: avg_server_running_ns
    label: 对应 server 线程平均 Running
    type: duration
    unit: ns
    format: duration_ms
  - name: avg_server_state_observed_ns
    label: 对应 server 线程平均状态覆盖
    type: duration
    unit: ns
    format: duration_ms
  - name: headroom_status
    label: 余量测量状态
    type: string
  - name: limitation
    label: 边界
    type: string
save_as: camera_binder_execution
synthesize:
  role: overview
  fields:
  - key: client_upid
    label: Client UPID
  - key: server_upid
    label: Server UPID
  - key: client_process
    label: Client 进程
  - key: server_process
    label: Server 进程
  - key: transactions
    label: 完整同步事务数
  - key: avg_client_wall_ns
    label: Client 平均 wall
  - key: avg_server_wall_ns
    label: Server 平均 wall
  - key: server_state_observed_txns
    label: 有 server 线程状态的事务数
```
### Camera 证据覆盖

- ID: `evidence_coverage`
- Type: `atomic`
- SQL: [`../sql/camera_trace_evidence/evidence_coverage.sql`](../sql/camera_trace_evidence/evidence_coverage.sql)

```yaml
id: evidence_coverage
type: atomic
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
process_scope:
  role: global_context
  limitations:
  - Trace-wide camera/media context grouped by observed identities; not filtered to a target UPID.
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
