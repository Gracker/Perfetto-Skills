GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/camera_pipeline.skill.yaml
Source SHA-256: 479ed093fa26fc6b133ceba6ba4af413e76bb97701a20becb96ed562ee5adfeb
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# 相机管线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
  - sensor_exposure_capture_rhythm
deviation_anchors: no_vsync_app_hardware_sensor_trigger
subvariants_note: '文章 S11 把 Camera 类型拆为 4 个子变种：

  - CAMERA_PREVIEW_SURFACEVIEW（预览独立 SV，zero-copy overlay 理想路径）

  - CAMERA_PREVIEW_TEXTUREVIEW（预览回宿主 TV，宿主采样路径）

  - CAMERA_IMAGEANALYSIS_READER（分析路径 ImageReader）

  - CAMERA_VIDEORECORD_SURFACE（录像 Surface）

  Phase E 拆分独立 ID。当前 ID 一并覆盖。

  '
multi_output_back_pressure: 'Camera 多路输出（preview/analysis/record）共享同一 capture pipeline——

  任一路消费慢会 back-pressure 整段 pipeline，导致预览看似"卡"实际是被某路拖慢。

  分析时必须分开看 3 路。

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

  涉及相机硬件、ISP、编码器等多个组件的协同工作。

  需要关注帧率稳定性和延迟。Camera trace 的可见性强依赖设备、

  OEM 和启用的数据源，不应把缺失某个 `Camera*` slice 直接等价为“没有相机压力”。

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
  description: 相机相关操作（是否可见依设备 / tracing 配置）
- name: CaptureSession
  thread: any
  description: 采集会话（名称与可见性依版本 / OEM 变化）
- name: createCaptureSession
  thread: any
  description: 创建采集会话（常见于启动/切换摄像头/重配流）
- name: setRepeatingRequest
  thread: any
  description: 预览/录制的重复请求（影响吞吐与延迟）
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
  description: 'Camera 多路输出（preview/analysis/record）共享同一 capture pipeline。

    任一路消费慢（典型如 ImageReader 不及时 release / Codec 堆积）会 back-pressure HAL，

    让预览看似卡顿。分析时必须分别看三路输出谁在回压，不能只盯 HAL 慢。

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
  description: '预览承载若是 TextureView，宿主 RT updateTexImage acquire + GPU 重采样会引入额外延迟（通常 +1 帧）。

    SurfaceView 模式可走 device composition 避免此开销。

    '
  detection_skill: render_thread_slices
- id: sensor_trigger_not_vsync_aligned
  name: sensor 采集节奏不对齐 vsync
  description: 'Camera 帧率不等于显示刷新率（典型 30fps 视频拍摄在 60Hz 屏）。

    分析卡顿要分别看 capture frame rate（HAL processCaptureResult 频率）vs preview display frame rate（SF latch 频率）。

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
  reason: VSync (预览开始生产帧)
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
