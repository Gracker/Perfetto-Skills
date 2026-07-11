GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/vulkan_native.skill.yaml
Source SHA-256: 276ac4a394ba55e2936cc28bcc239d0bd485c4cb17c4b3e12fde9490bede6462
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# Vulkan Native

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

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
doc_path: rendering_pipelines/vulkan_native.md
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
title: Vulkan Native 渲染管线
summary: '使用 Vulkan API 进行高性能渲染。Vulkan 提供更低的 CPU 开销、

  更好的多线程支持和更精细的 GPU 控制。适用于高端游戏和专业图形应用。

  Swappy 库可提供更稳的帧节拍控制。不要把 `vkAcquireNextImageKHR` /

  `vkQueuePresentKHR` 是否阻塞当作固定行为，它们在不同设备上可能表现不同。

  '
mermaid: "sequenceDiagram\n  participant App as App Thread\n  participant VK as Vulkan Thread\n  participant Swappy as Frame\
  \ Pacing\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over\
  \ App,SF: \U0001F4CD Vulkan Native 渲染链路\n  VK->>VK: vkAcquireNextImage\n  activate VK\n  VK->>VK: vkBeginCommandBuffer\n\
  \  VK->>VK: Record Draw Commands\n  VK->>VK: vkEndCommandBuffer\n  VK->>VK: vkQueueSubmit\n  VK->>VK: vkQueuePresentKHR\n\
  \  deactivate VK\n\n  Swappy-->>VK: Frame Pacing 控制\n  BQ-->>SF: Buffer Ready\n  VS->>SF: \U0001F514 VSync-sf\n  activate\
  \ SF\n  SF->>SF: latchBuffer\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over App,SF: \U0001F680 现代高性能图形 API，支持 Frame\
  \ Pacing\n"
thread_roles:
- thread: main
  role: 应用逻辑
  description: 游戏/应用主循环
- thread: Vulkan
  role: Vulkan 渲染线程
  description: 记录/提交 Vulkan 命令（线程名通常包含 Vulkan/Vk/Render 等关键词）
- thread: SurfaceFlinger
  role: 合成显示
  description: latch Buffer 并提交到 HWC
key_slices:
- name: vkQueuePresentKHR
  thread: any
  description: 提交帧到显示；可见但不代表其阻塞行为稳定
- name: vkCmdDraw*
  thread: any
  description: Vulkan 绘制命令
- name: Swappy
  thread: any
  description: 帧节拍控制
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
