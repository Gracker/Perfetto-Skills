GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/imagereader_pipeline.skill.yaml
Source SHA-256: c016399e110f9f3bfe0ba8f599e4ad9a59889ac2c2eea78845816dd4c56a90fd
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa
# ImageReader 渲染管线

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
doc_path: rendering_pipelines/imagereader_pipeline.md
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

  Phase E 评估是否拆分。

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
title: ImageReader 渲染管线
summary: 'ImageReader 允许应用直接访问渲染到 Surface 的图像数据。它底层基于 BufferQueue，

  作为 consumer 端从 producer（Camera HAL、MediaCodec 解码器、GPU 渲染等）获取帧。


  典型使用场景：

  - ML 推理：获取 Camera/GPU 帧进行实时模型推理

  - 屏幕录制：捕获渲染帧编码为视频

  - 自定义相机处理：Camera2 API + ImageReader 实现自定义 ISP

  - 部分 Chrome 渲染模式：通过 ImageReader 获取合成帧


  关键特征：

  - Java API: `ImageReader.newInstance()` + `onImageAvailable` 回调

  - NDK API: `AImageReader_new()` + `AImageReader_ImageListener`

  - 与 HardwareBuffer 结合可实现零拷贝跨进程/跨 GPU 帧传递

  - maxImages 参数控制 BufferQueue 深度，影响内存占用和延迟

  '
mermaid: "sequenceDiagram\n  participant P as Producer<br/>(Camera/GPU/Codec)\n  participant BQ as BufferQueue\n  participant\
  \ IR as ImageReader\n  participant App as App (Consumer)\n  participant Proc as Processing<br/>(ML/Encode/Display)\n\n \
  \ Note over P,Proc: \U0001F4CD ImageReader 帧获取流程\n  P->>BQ: dequeueBuffer\n  P->>P: 渲染/解码/捕获\n  P->>BQ: queueBuffer (帧就绪)\n\
  \n  BQ->>IR: onImageAvailable 回调\n  activate IR\n  IR->>App: 通知新帧可用\n  deactivate IR\n\n  activate App\n  App->>IR: acquireNextImage\n\
  \  IR->>BQ: acquireBuffer (获取帧)\n  IR-->>App: Image (HardwareBuffer)\n  App->>Proc: 处理帧 (ML 推理/编码/展示)\n  App->>IR: Image.close()\n\
  \  IR->>BQ: releaseBuffer\n  deactivate App\n\n  Note over P,Proc: ⏱️ 关键耗时点：queueBuffer→回调延迟、帧处理耗时、Buffer 释放速度\n"
thread_roles:
- thread: main
  role: 应用主线程
  description: 配置 ImageReader, 注册回调, 管理生命周期
  trace_tags: bindApplication, activityStart, ImageReader
- thread: ImageReader
  role: ImageReader 回调
  description: 处理 onImageAvailable 回调, 获取和释放 Image
  trace_tags: ImageReader, onImageAvailable, acquireNextImage
- thread: Producer
  role: 帧生产者
  description: 帧生产线程 — 可以是 Camera HAL, MediaCodec 解码器, 或 GPU 渲染线程
  trace_tags: Camera, MediaCodec, dequeueBuffer, queueBuffer
key_slices:
- name: acquireNextImage
  thread: any
  description: 获取下一帧 Image — 从 BufferQueue 获取渲染好的帧
- name: onImageAvailable
  thread: any
  description: 帧可用回调 — ImageReader 通知应用有新帧
- name: queueBuffer
  thread: any
  description: 提交 Buffer — 生产者将渲染好的帧提交到 BufferQueue
- name: HardwareBuffer
  thread: any
  description: 硬件 Buffer 操作 — GPU/Camera/Codec 直接读写
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
