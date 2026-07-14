GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/hardware_buffer_renderer.skill.yaml
Source SHA-256: f5c8504e0f47225e7f38c91e84aab2c8bbba582347aea5ea42e5a0b0d9957d0a
Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba
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
doc_path: rendering_pipelines/S07_software_offscreen_type.md
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

  该条目在 catalog 中是 S07 的 feature 证据，不参与主类型竞争；

  OFFSCREEN_BITMAP 仍由 S07 文档中的子路径解释。

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
source: rendering_pipelines/S07_software_offscreen_type.md
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
