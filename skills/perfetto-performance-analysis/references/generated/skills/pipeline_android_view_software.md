GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_view_software.skill.yaml
Source SHA-256: 5de7469c18f360c86b277d6c21f8979afdb2885745cb8dad15682a2469eb44bd
Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49
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
doc_path: rendering_pipelines/S07_software_offscreen_type.md
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

  这些子路径统一映射到 S07；只有 catalog 标记为 variant 的条目参与主类型判定，

  HardwareBufferRenderer、ImageReader 等条目作为 feature 保留附加证据。

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
source: rendering_pipelines/S07_software_offscreen_type.md
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

    当前 ID 因 exclude_if RenderThread 排除此场景；该现象作为 S07 内的软件 layer 子路径说明，

    不单独提升为主渲染类型。

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
