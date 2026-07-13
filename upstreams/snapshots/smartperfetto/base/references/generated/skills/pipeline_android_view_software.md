GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_software.skill.yaml
Source SHA-256: ea10f9b97631e7af7693b5222246eb59e8e430fbbe8909533854db85d0095668
Source commit: 40048058243cbb91ef11082a06ba1e4d0f7d3c5a
# Android View 软件渲染

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_view_software
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_VIEW_SOFTWARE
display_name: Android View 软件渲染
description: CPU Skia 软件渲染，无 RenderThread，用于低端设备或特殊场景
icon: cpu
family: hwui
doc_path: rendering_pipelines/android_view_software.md
s_article_ref: S07
four_features:
  producer_threads:
  - main
  expected_layer_count: 1
  bufferqueue_path: ACQUIRE_FENCE_NONE_INPROC
  extra_rhythm_sources: []
deviation_anchors: skips_renderthread_anchor_5
subvariants_note: '文章 S07 把 software/离屏拆为 4 子变种：

  1. SOFTWARE_RENDERING_CANVAS（整窗 lockCanvas，无 RenderThread）— 当前 ID 主要覆盖

  2. SOFTWARE_RENDERING_LAYER（View.setLayerType(LAYER_TYPE_SOFTWARE)，混合路径，仍有 RenderThread + Bitmap upload）— 当前 exclude_if
  RenderThread 排除掉

  3. OFFSCREEN_HARDWAREBUFFER（HardwareBufferRenderer 离屏 GPU，Android 14+/API 35）

  4. OFFSCREEN_BITMAP（离屏 Bitmap + 纹理上传）

  Phase E 会拆分独立 ID。

  article-precise slice 名（用于 LLM 诊断参考）：

  - nSurface_lockCanvas / nSurface_unlockCanvasAndPost（native 层 Surface 操作）

  - drawSoftware（ViewRootImpl.drawSoftware()）

  - copyBlt（dirty region 模式下从旧 buffer 抄 non-dirty 像素）

  '
```

## Detection

```yaml
required_signals:
- thread: main
  min_count: 1
scoring_signals:
- signal: has_lock_canvas
  slice_pattern: '*lockCanvas*'
  weight: 55
- signal: has_unlock_canvas_post
  slice_pattern: '*unlockCanvasAndPost*'
  weight: 55
exclude_if:
- thread: RenderThread
- slice_pattern: DrawFrame*
```

## Teaching model

```yaml
title: Android View 软件渲染管线
summary: '使用 CPU Skia 进行软件渲染，所有绘制都在主线程完成。

  通常用于低端设备、特殊 View (如 SurfaceHolder.lockCanvas)，或硬件加速被禁用时。

  性能较低，但兼容性最好。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant Canvas as Canvas\
  \ (CPU)\n  participant BQ as BufferQueue\n  participant VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over\
  \ VA,SF: \U0001F4CD Software Rendering (无 RenderThread)\n  VA->>Main: \U0001F514 VSync-app 信号触发\n  activate Main\n  Main->>Main:\
  \ Choreographer#doFrame\n  Main->>Canvas: lockCanvas\n  Main->>Canvas: Skia CPU 绘制 (drawXXX)\n  Main->>Canvas: unlockCanvasAndPost\n\
  \  Main->>BQ: queueBuffer\n  deactivate Main\n\n  VS->>SF: \U0001F514 VSync-sf 触发\n  activate SF\n  SF->>SF: latchBuffer\n\
  \  SF->>SF: HWC Composite\n  deactivate SF\n\n  Note over VA,SF: ⚠️ 无硬件加速，适用于简单 UI 或兼容模式\n"
thread_roles:
- thread: main
  role: UI 构建 + 渲染
  description: Measure/Layout/Draw 全在主线程，使用 CPU Skia 渲染
key_slices:
- name: lockCanvas
  thread: main
  description: 获取 CPU 画布
- name: unlockCanvasAndPost
  thread: main
  description: 提交绘制结果
```

## Analysis guidance

```yaml
common_issues:
- id: cpu_bottleneck
  name: CPU 渲染瓶颈
  description: 软件渲染占用大量 CPU 时间
  detection_skill: cpu_analysis
- id: dirty_region_copyblt_overhead
  name: Dirty region copyBlt 开销
  description: 'Surface::lock(dirty) 带 dirty region 调用时，frameworks/native/libs/gui/Surface.cpp

    会通过 copyBlt(backBuffer, frontBuffer, copyback) 把上一帧 non-dirty 像素抄到新 buffer。

    即使 dirty 区域很小，仍有 buffer 拷贝开销；新旧 buffer 尺寸/格式不一致时还会强制全重绘。

    S07 §"CPU software rendering 这一段在做什么"。

    '
  detection_skill: cpu_analysis
- id: no_acquire_fence_release_fence_still_present
  name: 无 acquire fence 但 release fence 仍存在
  description: '软件路径下 unlockAndPost 提交时 acquire fence = NO_FENCE，SF latch 无需等待。

    但 release fence 仍然存在：HWC presentDisplay 后通过 getReleaseFences() 返回，

    SF 经 BufferQueue 回传给 Producer 通知可重新 dequeue。Producer 仍可能卡 dequeueBuffer 等 release。

    '
  detection_skill: render_thread_slices
- id: software_layer_bitmap_upload
  name: LAYER_TYPE_SOFTWARE 的 Bitmap 上传开销
  description: '若某 View 设了 LAYER_TYPE_SOFTWARE，子树会被绘制到离屏 Bitmap 再由 HWUI 作为纹理上传参与 GPU 合成。

    Trace 中表现为 RenderThread 仍存在（与纯软件不同），但额外伴随 Bitmap 分配 + uploadToTexture slice。

    当前 ID 因 exclude_if RenderThread 排除此场景；Phase E 拆 SOFTWARE_RENDERING_LAYER 独立 ID。

    '
  detection_skill: render_thread_slices
recommended_skills:
- cpu_analysis
- scheduling_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (App 开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: CPU 软件渲染 (Skia)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程（软件渲染通常由 lockCanvas/unlockCanvasAndPost 驱动）
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 3
  reason: VSync (SurfaceFlinger 消费/合成)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 4
  reason: SurfaceFlinger (最终合成/显示)
  main_thread_only: true
```
