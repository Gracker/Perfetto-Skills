GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/camera_pipeline.skill.yaml
Source SHA-256: 55ab9f0f50c5deaffb9d814b65ad0cd7466569d27d66aaa17188f4c9ed38f250
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# 相机管线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_camera_pipeline
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: CAMERA_PIPELINE
display_name: 相机管线
description: Camera2/HAL3 多流相机渲染
icon: camera
family: specialized
doc_path: rendering_pipelines/camera_pipeline.md
s_article_ref: S11
four_features:
  producer_threads:
  - cameraserver
  - camera HAL
  - Camera*
  - RequestThread
  - CaptureSession
  optional_consumer_threads:
  - RenderThread
  - ImageReader
  - media.codec
  expected_layer_count: 1
  bufferqueue_path: HAL_PRODUCED_TO_PREVIEW_SURFACE_OR_IMAGEREADER
  extra_rhythm_sources:
  - camera_request_activity
deviation_anchors: no_vsync_app_camera_request_activity_candidate
subvariants_note: '文章 S11 把 Camera 类型拆为 4 个子变种：

  - CAMERA_PREVIEW_SURFACEVIEW（预览独立 SV，zero-copy overlay 理想路径）

  - CAMERA_PREVIEW_TEXTUREVIEW（预览回宿主 TV，宿主采样路径）

  - CAMERA_IMAGEANALYSIS_READER（分析路径 ImageReader）

  - CAMERA_VIDEORECORD_SURFACE（录像 Surface）

  Phase E 拆分独立 ID。当前 ID 一并覆盖。

  '
multi_output_back_pressure: 'Camera 多路输出（preview/analysis/record）可能共享硬件与 buffer 资源。

  只有存在 buffer ownership、acquire/release 或 fence 等证据时，才能把某一路消费慢报告为

  整体 pipeline back-pressure；仅凭 PSS/RSS 增长不能判定 ImageReader 泄漏。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_camera_thread
  thread_pattern: '*Camera*'
  weight: 30
- signal: has_cam_abbrev_thread
  thread_pattern: '*Cam*'
  weight: 10
- signal: has_camera_slice
  slice_pattern: '*Camera*'
  weight: 30
- signal: has_capture_session
  slice_pattern: '*CaptureSession*'
  weight: 30
```

## Teaching model

```yaml
title: 相机渲染管线
summary: 'Camera2 API 和 HAL3 相机架构，支持多流同时处理（预览、拍照、录像）。

  Request 按序提交，但可有多个 request 同时 in-flight；每个 request 可产生 partial metadata

  和一个或多个输出 buffer。`onOpened` 只证明设备打开完成，不证明首个 result、buffer 或预览呈现。

  首帧需要稳定的 session/camera identity，以及明确的 request/result/buffer/presentation 锚点；

  vendor slice-name inventory 只能作为 candidate，不能单独证明首帧。首帧到达时 3A 仍可能搜索，

  有 trace 证据时应单独报告 3A 状态。`prepare()` 是 buffer 预分配取舍，可能推迟首次输出并增加内存，

  不是通用首帧修复。ZSL 行为和 buffer topology 取决于 capability、实现与 App 配置。

  ImageReader backpressure 只有在 buffer ownership/acquire-release 证据存在时才是受支持的假设；

  PSS/RSS 增长本身不足以判定泄漏。Pixel `pixel.camera` 解析只是可选 vendor fast path，

  不是可移植的 Android Camera contract。Camera trace 可见性强依赖设备、OEM 和启用的数据源。

  '
mermaid: "sequenceDiagram\n  participant App as App\n  participant Cam as CameraService\n  participant HAL as Camera HAL\n\
  \  participant ISP as ISP/GPU\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\
  \n  Note over App,SF: \U0001F4CD Camera2/HAL3 渲染链路\n  App->>Cam: createCaptureSession\n  App->>Cam: setRepeatingRequest\n\
  \n  activate HAL\n  HAL->>ISP: 配置图像处理流水线\n  loop 每帧\n    HAL->>HAL: 捕获 Bayer 数据\n    HAL->>ISP: 3A + ISP 处理\n    ISP->>BQ:\
  \ 输出到 Surface\n  end\n  deactivate HAL\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: latchBuffer\n  SF->>SF:\
  \ HWC Composite\n  deactivate SF\n\n  Note over App,SF: \U0001F4F7 支持预览/录制/拍照多路输出\n"
thread_roles:
- thread: Camera
  role: 相机服务
  description: Camera2 API 和相机服务（线程名 / slice 名依设备而异）
- thread: CaptureSession
  role: 采集会话
  description: 相机采集会话管理
key_slices:
- name: Camera
  thread: any
  description: 相机相关操作候选（vendor 名称不能单独证明 request/result/buffer 阶段）
- name: CaptureSession
  thread: any
  description: 采集会话活动候选（名称与可见性依版本 / OEM 变化）
- name: createCaptureSession
  thread: any
  description: 创建采集会话候选（常见于启动/切换摄像头/重配流）
- name: setRepeatingRequest
  thread: any
  description: 预览/录制重复 request activity candidate（不能据此推断 sensor trigger）
```

## Analysis guidance

```yaml
common_issues:
- id: preview_jank
  name: 预览卡顿
  description: 相机预览帧率不稳定
  detection_skill: sf_frame_consumption
- id: multi_output_back_pressure
  name: 多路输出 back-pressure 拖慢预览
  description: 'Camera 多路输出（preview/analysis/record）可能竞争共享硬件与 buffer 资源。

    ImageReader 未及时 release / Codec 堆积导致 HAL back-pressure 只能作为候选解释；

    需要 buffer ownership、acquire/release 或 fence 证据支持，不能仅凭 PSS/RSS 增长判定泄漏。

    '
  detection_skill: gpu_render_in_range
- id: release_fence_late_blocks_hal
  name: Release fence 晚回阻塞 HAL
  description: '消费侧 release fence 晚回（HWC/SurfaceFlinger/宿主采样/Codec 编码） →

    HAL 拿不到新 buffer → request pipeline 整体 back-pressure。

    '
  detection_skill: present_fence_timing
- id: textureview_extra_resample_overhead
  name: TextureView 模式宿主 RT 采样开销
  description: '预览承载若是 TextureView，宿主 RT updateTexImage acquire + GPU 重采样可能引入额外延迟。

    SurfaceView 模式在设备与合成条件允许时可走 device composition 避免此开销。

    '
  detection_skill: render_thread_slices
- id: camera_request_activity_not_vsync_aligned
  name: Camera request activity candidate 不对齐 vsync
  description: 'Camera 帧率不等于显示刷新率（典型 30fps 视频拍摄在 60Hz 屏）。

    `processCaptureRequest*` 等名称匹配只能标记 Camera request activity candidate，不能证明 sensor trigger。

    分析卡顿要分别看有明确 identity 的 request/result/buffer 证据与 preview presentation 频率。

    '
  detection_skill: vsync_alignment_in_range
recommended_skills:
- sf_frame_consumption
- cpu_analysis
- present_fence_timing
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (宿主 UI/控制层节奏，不证明相机像素生产)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: 相机 UI/业务逻辑 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程（避免 pin 到系统/其他 app 的 main）
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: 预览 UI 渲染 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread（若预览走纯 SurfaceView 可能为空）
- pattern: CaptureSession
  match_by: name
  priority: 4
  reason: 采集会话 (生产)
- pattern: Camera
  match_by: name
  priority: 5
  reason: Camera 服务 (传输)
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 5.5
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^BufferTX
  match_by: name
  priority: 6
  reason: BufferTX (SurfaceFlinger 事务)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 7
  reason: 预览合成/显示
  main_thread_only: true
```
