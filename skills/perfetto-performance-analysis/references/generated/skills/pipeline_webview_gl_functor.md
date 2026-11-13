GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/webview_gl_functor.skill.yaml
Source SHA-256: 7191fa7f411863e906bfc4eb3c76abdbd3c95ffd834321cb2f793906d4c168e1
# WebView GL Functor

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_webview_gl_functor
version: '1.0'
type: pipeline_definition
category: rendering
```

## Product teaching card

[Read the local teaching card](../knowledge/rendering-teaching.md#s09_webview). This is reference topology; verify observed handoffs in the trace.

## Metadata

```yaml
pipeline_id: WEBVIEW_GL_FUNCTOR
display_name: WebView GL Functor
description: WebView GLES/Vulkan functor 在宿主 RenderThread 消费网页资源并绘制
icon: web
family: webview
doc_path: references/generated/knowledge/rendering-teaching.md#s09_webview
s_article_ref: S09
four_features:
  producer_threads:
  - RenderThread
  - CrRendererMain
  - Compositor
  - CompositorTileWorker*
  optional_producer_threads:
  - VizCompositorThread
  expected_layer_count: 0
  bufferqueue_path: CHROMIUM_DDL_TO_HOST_RENDERTHREAD_REPLAY
  extra_rhythm_sources:
  - chromium_compositor_rhythm
deviation_anchors: host_rt_replay_anchor_5_at_host_rt
layer_signature: 宿主 window layer 1 个（网页内容已被宿主吸收）
subvariants_note: '文章 S09 区分 5 种 WebView 路径：

  - WEBVIEW_GL_FUNCTOR（当前 ID）— Functor，回宿主 RT

  - WEBVIEW_SURFACE_CONTROL — SurfaceControl overlay，独立合成

  - WEBVIEW_SURFACEVIEW_WRAPPER — 网页独立 SurfaceView（典型全屏视频）

  - WEBVIEW_TEXTUREVIEW_CUSTOM — 第三方内核 TextureView

  - WEBVIEW_IMAGEREADER_PIPELINE — 罕见中转路径

  '
thread_locations: 'Blink/renderer 可在独立 sandboxed_process，functor sync/draw 在宿主 App 的 HWUI RenderThread。

  DrawFn_DrawGL/DrawVk 与 WebViewFunctor::drawGl/drawVk 是不同版本的 draw 名称；

  sync、postDraw、init 与 reparent 不能当成新内容帧或 physical present。

  '
```

## Detection

```yaml
required_signals:
- thread: RenderThread
  min_count: 1
- slice_patterns:
  - DrawGL*
  - '*DrawFn_DrawGL*'
  - '*DrawFn_DrawVk*'
  - '*DrawFunctor*'
  - AwDrawFnImpl::Draw[GV][Llk]*
  - WebViewFunctor::draw[GgVv][LlKk]*
  min_count: 1
scoring_signals:
- signal: has_draw_gl
  slice_patterns:
  - DrawGL*
  - '*DrawFn_DrawGL*'
  - '*DrawFn_DrawVk*'
  - '*DrawFunctor*'
  - AwDrawFnImpl::Draw[GV][Llk]*
  - WebViewFunctor::draw[GgVv][LlKk]*
  weight: 25
- signal: has_cr_renderer
  thread_pattern: CrRendererMain*
  weight: 25
- signal: has_render_thread
  thread_pattern: RenderThread*
  weight: 10
exclude_if:
- thread: 1.ui
```

## Teaching model

```yaml
source: references/generated/knowledge/rendering-teaching.md#s09_webview
```

## Analysis guidance

```yaml
common_issues:
- id: functor_wait
  name: Functor 等待
  description: RenderThread 等待 WebView 完成
  detection_skill: render_thread_slices
- id: js_long_task
  name: JS 长任务
  description: JavaScript 执行阻塞渲染
  detection_skill: cpu_analysis
- id: host_renderthread_overrun_via_functor
  name: 宿主 RT 因 functor replay 段超 budget
  description: 'DrawFn_DrawGL/DrawVk 或 WebViewFunctor::drawGl/drawVk 在宿主 RT 消费网页合成描述与资源。

    外层 wall time 可包含等待与 RunTasks，先区分 Running/Runnable/Sleeping，再追 Viz、资源与 GPU。

    '
  detection_skill: render_thread_slices
- id: chromium_renderer_jank
  name: Chromium Renderer 卡导致网页更新晚
  description: 'CrRendererMain 上 Blink Layout/Paint 重，或 Compositor 工作晚，可能让宿主继续使用旧网页 frame/resource。

    宿主 RT 看不出这一帧"为什么晚了"，要切到 Chromium 线程上找。

    '
  detection_skill: cpu_analysis
- id: blink_v8_long_task
  name: Blink V8 长任务（>50ms）
  description: 'JS 执行长任务（>50ms）阻塞 Renderer 主线程，导致后续 input/animation 都卡。

    Web Vitals 中的 INP/TBT 与此直接相关。

    '
  detection_skill: cpu_analysis
recommended_skills:
- render_thread_slices
- cpu_analysis
- binder_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (WebView 开始生产帧)
- pattern: ^main(\s+\d+)?$
  match_by: name
  priority: 2
  reason: WebView 宿主 UI (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的宿主主线程
- pattern: CrRendererMain
  match_by: name
  priority: 3
  reason: Chromium 主渲染 (生产/传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 属于当前 app 的 Chromium 渲染进程（多 app trace 下减少噪音）
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 4
  reason: App RenderThread (传输/合成)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread
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
