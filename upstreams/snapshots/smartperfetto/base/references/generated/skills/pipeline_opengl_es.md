GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/opengl_es.skill.yaml
Source SHA-256: 718020f1cf9590a3a6fa703c9005e87e0701a56c4b21d2ac3211cbdf3458d809
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# OpenGL ES

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_opengl_es
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: OPENGL_ES
display_name: OpenGL ES
description: 直接 OpenGL ES / EGL 渲染，用于游戏和自定义渲染引擎
icon: gpu
family: graphics
doc_path: rendering_pipelines/opengl_es.md
s_article_ref: S08
four_features:
  producer_threads:
  - GLThread
  optional_producer_threads:
  - RenderThread
  - '*EGL*'
  - engine threads
  expected_layer_count: 1
  bufferqueue_path: ANATIVEWINDOW_BUFFERQUEUE
  extra_rhythm_sources:
  - app_render_loop
  - swappy_pacing
deviation_anchors: app_render_loop_anchor_4_5_6_no_view_root
subvariants_note: '文章 S08 列出几个相关子变种：NATIVEACTIVITY_MAIN（NativeActivity 纯 native 线程）、

  GAMEACTIVITY_MAIN（GameActivity 现代替代品）。当前 ID 主要覆盖 GLSurfaceView/GLThread 模式。

  '
```

## Detection

```yaml
required_signals:
- thread_pattern: '*GLThread*'
  min_count: 1
scoring_signals:
- signal: has_egl_swap
  slice_pattern: '*eglSwapBuffers*'
  weight: 50
- signal: has_gl_draw
  slice_pattern: '*glDraw*'
  weight: 20
- signal: has_gl_thread
  thread_pattern: '*GLThread*'
  weight: 15
exclude_if:
- slice_pattern: '*vkQueuePresentKHR*'
- slice_pattern: '*ANGLE*'
- thread: 1.ui
- thread: CrRendererMain
- thread: UnityMain
```

## Teaching model

```yaml
title: OpenGL ES 渲染管线
summary: '直接使用 OpenGL ES 和 EGL API 进行渲染。适用于自定义游戏引擎、

  3D 应用等需要精细控制 GPU 的场景。通过 eglSwapBuffers 提交帧。

  在新设备上也要考虑 ANGLE 作为可选后端的可能性，但不应假设所有 GLES 都会被强制翻译到 Vulkan。

  '
mermaid: "sequenceDiagram\n  participant App as App Thread\n  participant GL as GLThread\n  participant EGL as EGL Context\n\
  \  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over App,SF:\
  \ \U0001F4CD OpenGL ES 渲染链路\n  GL->>EGL: eglMakeCurrent\n  activate GL\n  GL->>GL: glClear / glDraw*\n  GL->>GL: GPU 命令提交\n\
  \  GL->>EGL: eglSwapBuffers\n  EGL->>BQ: queueBuffer\n  deactivate GL\n\n  VS->>SF: \U0001F514 VSync-sf\n  activate SF\n\
  \  SF->>SF: latchBuffer\n  SF->>SF: HWC 合成\n  deactivate SF\n\n  Note over App,SF: \U0001F3AE 传统 OpenGL ES 游戏/渲染引擎常用\n"
thread_roles:
- thread: GLThread
  role: GL 渲染线程
  description: 执行 OpenGL 绘制命令
- thread: SurfaceFlinger
  role: 合成显示
  description: latch Buffer 并提交到 HWC
key_slices:
- name: eglSwapBuffers
  thread: GLThread
  description: 交换 Buffer，提交帧
- name: glDraw*
  thread: GLThread
  description: OpenGL 绘制调用
```

## Analysis guidance

```yaml
common_issues:
- id: gl_driver_stall
  name: GL 驱动阻塞
  description: glFinish 或 eglSwapBuffers 等待过长
  detection_skill: gpu_analysis
- id: egl_swap_blocked_by_release_fence
  name: eglSwapBuffers 阻塞等 release fence
  description: 'eglSwapBuffers 长等可能不是 GPU 慢——是 release fence 没回（HWC 还没释放上一帧 buffer）

    或 swapchain 内 buffer 用完。隐式管理下原因不直接可见。S08 §"Vulkan 的 vkAcquireNextImageKHR 长等"对照。

    '
  detection_skill: gpu_render_in_range
- id: swappy_pacing_alignment_wait
  name: Swappy frame pacing 对齐等待
  description: '启用 Swappy（SwappyGL_swap）时若帧超 budget，会被强制推迟到下个 vsync 对齐——这是设计行为不是 jank。

    但若超 budget 频繁会让有效帧率从 60→30。

    '
  detection_skill: vsync_phase_alignment
- id: pre_rotation_missing
  name: 未处理 pre-rotation 触发系统侧补旋转
  description: 'App 责任处理 pre-rotation。未处理时系统侧补旋转引入额外延迟和 GPU 开销（横竖屏切换、外接显示场景明显）。

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
- pattern: GLThread
  match_by: name
  priority: 2
  reason: GL 渲染线程 (生产/传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 GLThread
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: RenderThread (如存在，用于 View 系统合成)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread（混合场景下可用）
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
