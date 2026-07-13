GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/hardware_buffer_renderer.skill.yaml
Source SHA-256: 77f0c16c98124ea632834a8112a8afcd6458b6a40457d6f5fe010817005b0bbc
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# HardwareBufferRenderer

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_hardware_buffer_renderer
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: HARDWARE_BUFFER_RENDERER
display_name: HardwareBufferRenderer
description: Android 14+ HBR API，直接 Buffer 渲染
icon: memory
family: specialized
doc_path: rendering_pipelines/hardware_buffer_renderer.md
s_article_ref: S07
four_features:
  producer_threads:
  - main
  - RenderThread
  expected_layer_count: 0
  bufferqueue_path: OFFSCREEN_HARDWAREBUFFER + SURFACECONTROL_TRANSACTION_DIRECT
  extra_rhythm_sources: []
deviation_anchors: offscreen_hardwarebuffer_anchor_5_no_bbq_anchor_6
android_version: 'Android 14 AOSP 已存在但 @hide / @SystemApi；Android 15 / API 35 才正式公开。

  Android 10-13 的离屏硬件渲染通常通过 HardwareRenderer + setSurface() 或 EGL 离屏 context + HardwareBuffer 组合实现。

  '
subvariants_note: '文章 S07 把 software/离屏拆为 4 子变种，HBR 对应：

  OFFSCREEN_HARDWAREBUFFER（HardwareBufferRenderer 离屏 GPU，Android 14+/API 35）。

  Phase E 拆 OFFSCREEN_BITMAP（离屏 Bitmap + 纹理上传）独立 ID。

  '
no_bbq_implication: '离屏结果直接通过 SurfaceControl.Transaction.setBuffer() 提交时跳过 BLASTBufferQueue。

  Trace 上看不到这条 layer 的 BufferTX counter——要从 SF 进程 transaction 接收点和 layer latch 看，

  不能按窗口提交习惯找 BBQ。S07 §"BufferQueue/queueBuffer/BufferTX 在这一类里怎么理解"。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_hardware_buffer_renderer
  slice_pattern: '*HardwareBufferRenderer*'
  weight: 55
- signal: has_ahardware_buffer_renderer
  slice_pattern: '*AHardwareBufferRenderer*'
  weight: 20
- signal: has_render_node
  slice_pattern: '*RenderNode*'
  weight: 15
- signal: has_recording_canvas
  slice_pattern: '*RecordingCanvas*'
  weight: 10
```

## Teaching model

```yaml
title: HardwareBufferRenderer 渲染管线
summary: 'Android 14+ 新增的 HardwareBufferRenderer API，提供 GPU 硬件加速的离屏渲染，

  替代传统的 lockCanvas() CPU 软件渲染。


  核心优势:

  - GPU 光栅化代替 CPU Skia 软件渲染

  - 直接渲染到 HardwareBuffer（是否零拷贝取决于后续合成/采样/拷贝链路）

  - 可选择 wide-gamut/HDR 相关 buffer format（取决于设备与格式支持，如 RGBA_FP16 等）

  - 显式 Fence 控制


  典型使用场景:

  - 自定义绘图引擎 (PDF 渲染器、矢量编辑器)

  - HDR 图像处理

  - 高帧率软件渲染

  '
mermaid: "sequenceDiagram\n  participant App as App\n  participant HBR as HardwareBufferRenderer\n  participant GPU as GPU\n\
  \  participant TX as Transaction\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over App,SF:\
  \ \U0001F4CD HardwareBufferRenderer (Android 14+)\n  App->>HBR: create (HardwareBuffer)\n  activate HBR\n  HBR->>GPU: GPU\
  \ 渲染到 HardwareBuffer\n  HBR->>HBR: 完成渲染\n  deactivate HBR\n\n  App->>TX: ASurfaceTransaction\n  App->>TX: setBuffer (HardwareBuffer)\n\
  \  TX->>SF: Transaction 提交\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: setTransactionState\n  SF->>SF:\
  \ latchBuffer\n  SF->>SF: HWC Composite\n  deactivate SF\n\n  Note over App,SF: \U0001F195 Android 14+ 新 API，无 SurfaceView\
  \ 开销\n"
thread_roles:
- thread: main
  role: HBR 控制
  description: 创建 HardwareBuffer，记录绘制命令
  trace_tags: HardwareBufferRenderer, RenderNode, RecordingCanvas
- thread: RenderThread
  role: GPU 光栅化
  description: 执行 RenderNode 的 GPU 渲染
  trace_tags: DrawRenderNode, GpuRasterize
- thread: SurfaceFlinger
  role: 合成显示
  description: 等待 Fence，合成 HardwareBuffer
key_slices:
- name: HardwareBufferRenderer
  thread: main
  description: HBR 生命周期操作 (create/draw/close)
- name: obtainRenderRequest
  thread: main
  description: 获取渲染请求
- name: RenderNode
  thread: main
  description: 绘制命令容器
- name: RecordingCanvas
  thread: main
  description: 记录绘制命令
- name: SyncFence
  thread: any
  description: GPU 完成同步 Fence
```

## Analysis guidance

```yaml
common_issues:
- id: hbr_fence_not_awaited
  name: Fence 未正确等待
  description: HBR submit 返回的 Fence 未等待即提交 Transaction
  detection_skill: present_fence_timing
- id: hbr_buffer_reuse
  name: Buffer 重用冲突
  description: 在 GPU 渲染完成前复用 HardwareBuffer
  detection_skill: gpu_analysis
- id: hbr_transaction_timing
  name: Transaction 提交时机不当
  description: HBR 内容未同步到 VSync
  detection_skill: vsync_alignment_in_range
- id: no_bufftx_counter_visible
  name: Trace 看不到该 layer 的 BufferTX
  description: 'HBR 直推 SurfaceControl.Transaction.setBuffer 时跳过 BBQ，trace 上看不到该 layer 的 BufferTX counter。

    排查时要从 SF 进程 transaction 接收点和 layer latch 看，不能按 BLAST 窗口经验找。

    '
  detection_skill: sf_composition_in_range
- id: consumer_late_consume_offscreen_invisible_to_sf
  name: 纯离屏场景 SF 看不到中间结果
  description: '若 HBR 输出仅供编码/缓存等纯离屏消费，SF 完全看不到这份内容。

    分析时要分别看"中间结果生产线程"和"最终消费者"，FrameTimeline 不适用。

    '
  detection_skill: gpu_render_in_range
recommended_skills:
- sf_frame_consumption
- gpu_analysis
- present_fence_timing
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: HBR 控制 (生产/传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程（避免 pin 到系统/其他 app 的 main）
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
  reason: 最终合成/显示
  main_thread_only: true
```
