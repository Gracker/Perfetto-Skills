GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/imagereader_pipeline.skill.yaml
Source SHA-256: 5b2ccd004a9c5954b77897842a72d4e07412657f67fe7305fd90b0634a2ece8a
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# ImageReader 渲染管线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_imagereader_pipeline
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: IMAGEREADER_PIPELINE
display_name: ImageReader 渲染管线
description: 通过 ImageReader API 获取渲染帧的管线，常见于 ML 推理、屏幕录制、自定义相机处理和部分 Chrome 渲染模式
icon: image
family: specialized
doc_path: rendering_pipelines/S07_software_offscreen_type.md
s_article_ref: S07
four_features:
  producer_threads:
  - any (Camera HAL / MediaCodec / GPU / Chromium)
  consumer_threads:
  - ImageReader callback thread
  - App thread (acquireNextImage)
  expected_layer_count: 0
  bufferqueue_path: BUFFERQUEUE_AS_CONSUMER
  extra_rhythm_sources:
  - producer_rhythm
deviation_anchors: cross_cutting_consumer_no_sf_anchor_7_to_12
cross_cutting_nature: 'ImageReader 不是独立 pipeline——它是任何 Producer 的可选消费者。

  可与 CAMERA_PIPELINE / VIDEO_OVERLAY_HWC / 任何渲染管线共存。

  Detection 标志着"App 主动消费帧做二次处理"（ML 推理 / 屏幕录制 / 自定义 ISP / 帧分析）。

  '
subvariants_note: '文章 S11 把 Camera ImageReader 路径单列为 CAMERA_IMAGEANALYSIS_READER 子变种。

  当前条目在 catalog 中作为 S07 的 feature 证据；Camera ImageAnalysis 语义由 S11 文档补充，

  不参与主类型竞争。

  '
```

## Detection

```yaml
required_signals:
- slice_pattern: '*ImageReader*'
  min_count: 1
scoring_signals:
- signal: has_acquire_next_image
  slice_pattern: '*acquireNextImage*'
  weight: 30
- signal: has_ndk_imagereader
  slice_pattern: '*AImageReader*'
  weight: 25
- signal: has_hardware_buffer
  slice_pattern: '*HardwareBuffer*'
  weight: 20
- signal: has_on_image_available
  slice_pattern: '*onImageAvailable*'
  weight: 20
- signal: has_queue_buffer
  slice_pattern: '*queueBuffer*'
  weight: 15
- signal: has_media_codec
  slice_pattern: '*MediaCodec*'
  weight: 10
```

## Teaching model

```yaml
source: rendering_pipelines/S07_software_offscreen_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: buffer_backpressure
  name: ImageReader Buffer 积压
  description: acquireNextImage 获取帧速度跟不上生产速度，导致 BufferQueue 满
  detection_skill: gpu_analysis
- id: callback_heavy
  name: onImageAvailable 回调耗时
  description: 回调中做了重计算 (ML 推理), 阻塞后续帧获取
  detection_skill: cpu_analysis
- id: cross_process_delay
  name: HardwareBuffer 跨进程传递延迟
  description: 当 producer 和 consumer 在不同进程时，Buffer 传递延迟增大
  detection_skill: binder_analysis
- id: imagereader_back_pressures_camera_hal
  name: ImageReader 回压 Camera HAL
  description: 'Camera 多路输出场景下，App 不及时 Image.close() 导致 ImageReader pool 满。

    backward pressure 经 BufferQueue 传到 HAL，HAL 拿不到 buffer slot 让 capture pipeline 整体停摆。

    分析时要看 acquireNextImage 频率与 close() 频率是否匹配。S11 §"buffer 回收压力"。

    '
  detection_skill: gpu_render_in_range
- id: maximages_too_low
  name: ImageReader maxImages 配置过小
  description: 'maxImages 决定 BufferQueue 深度，过小会触发 producer 频繁阻塞。

    典型经验：ML 推理场景 maxImages >= 2；高吞吐场景 >= 4。但越大越占内存。

    '
  detection_skill: memory_analysis
recommended_skills:
- gpu_analysis
- memory_analysis
- binder_analysis
- cpu_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 1
  reason: App 主线程 (配置 ImageReader)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程
- pattern: ImageReader
  match_by: name
  priority: 2
  reason: ImageReader 回调线程 (帧获取)
  expand: true
- pattern: Camera
  match_by: name
  priority: 3
  reason: Camera 服务 (帧生产者)
- pattern: MediaCodec
  match_by: name
  priority: 4
  reason: MediaCodec 解码 (帧生产者)
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
  reason: SurfaceFlinger (最终合成/显示)
  main_thread_only: true
```
