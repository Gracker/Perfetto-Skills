GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/vulkan_native.skill.yaml
Source SHA-256: f2ebbc1d3e8b4454f4ea200f00bca9f606746d70eb395cf18ebfba854d6c4d50
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864
# Vulkan Native

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_vulkan_native
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: VULKAN_NATIVE
display_name: Vulkan Native
description: 原生 Vulkan 渲染，现代高性能图形 API
icon: vulkan
family: graphics
doc_path: rendering_pipelines/S08_native_graphics_type.md
s_article_ref: S08
four_features:
  producer_threads:
  - graphics queue thread
  - presentation queue thread
  optional_producer_threads:
  - VkQueue*
  - '*Vulkan*'
  - RenderThread
  - engine threads
  expected_layer_count: 1
  bufferqueue_path: ANATIVEWINDOW_VULKAN_SWAPCHAIN
  extra_rhythm_sources:
  - app_render_loop
  - swappy_pacing
deviation_anchors: explicit_swapchain_anchor_4_5_6_no_view_root
subvariants_note: '文章 S08 列出 GameActivity 现代替代品（替代 NativeActivity）。

  Swappy 介入路径：SwappyVk_queuePresent 替代直接 vkQueuePresentKHR，提供 frame pacing。

  '
```

## Detection

```yaml
required_signals:
- slice_pattern: '*vkQueuePresentKHR*'
  min_count: 5
scoring_signals:
- signal: has_vk_present
  slice_pattern: '*vkQueuePresentKHR*'
  weight: 60
- signal: has_vk_cmd
  slice_pattern: '*vkCmd*'
  min_count: 10
  weight: 20
- signal: has_swappy
  slice_pattern: '*Swappy*'
  weight: 20
- signal: has_vulkan_thread
  thread_pattern: '*Vulkan*'
  weight: 6
- signal: has_vkqueue_thread
  thread_pattern: '*VkQueue*'
  weight: 4
- signal: has_vk_acquire
  slice_pattern: '*vkAcquireNextImage*'
  weight: 5
```

## Teaching model

```yaml
source: rendering_pipelines/S08_native_graphics_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: vk_queue_stall
  name: Vulkan 队列阻塞
  description: vkQueueSubmit 或 vkQueuePresentKHR 等待过长
  detection_skill: gpu_analysis
- id: vk_acquire_next_image_blocked_by_release_fence
  name: vkAcquireNextImageKHR 长等不是 GPU 慢
  description: 'vkAcquireNextImageKHR 长等的常见原因：上游消费慢导致 release fence 晚回，或 swapchain image 都用完。

    不是 GPU 渲染慢——是 Producer 拿不到可写 image slot。S08 §"vkAcquireNextImageKHR 长等"。

    '
  detection_skill: present_fence_timing
- id: pipeline_creation_jank
  name: vkCreateGraphicsPipelines 首次创建卡顿
  description: 'Vulkan pipeline 首次创建（含 shader 编译、PSO 状态预生成）成本高。

    若运行时按需创建会引入首帧/首场景卡顿。建议预热（pipeline cache）或离线编译。

    '
  detection_skill: jank_frame_detail
- id: swappy_pacing_alignment_wait
  name: Swappy/SwappyVk frame pacing 对齐等待
  description: '启用 SwappyVk_queuePresent 时若帧超 budget，会被强制推迟到下个 vsync——这是设计行为。

    超 budget 频繁会让有效帧率从 60→30/45。

    '
  detection_skill: vsync_phase_alignment
- id: pre_rotation_missing
  name: 未处理 pre-rotation 触发系统侧补旋转
  description: 'App 责任处理 pre-rotation。未处理时系统补旋转引入延迟（横竖屏切换、外接显示场景明显）。

    '
  detection_skill: gpu_render_in_range
recommended_skills:
- gpu_analysis
- gpu_metrics
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
  reason: 应用逻辑 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程
- pattern: ^RenderThread(\s+\d+)?$|Vulkan|Vk
  match_by: name
  priority: 3
  reason: Vulkan 渲染线程 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 Vulkan/渲染线程
- pattern: Swappy|FramePacing|VkQueue
  match_by: name
  priority: 4
  reason: 帧节拍/队列相关线程 (传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的帧节拍/队列线程
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
