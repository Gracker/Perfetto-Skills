GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/webview_gl_functor.skill.yaml
Source SHA-256: 70e83d7ea8c7de7cb707ee8f43dc18d1a91a936d7873e2abe816fe87cf00f679
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e
# WebView GL Functor

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_webview_gl_functor
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: WEBVIEW_GL_FUNCTOR
display_name: WebView GL Functor
description: 传统 WebView 渲染，App RenderThread 同步等待
icon: web
family: webview
doc_path: rendering_pipelines/webview_gl_functor.md
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
thread_locations: 'Chromium 线程可能在宿主 App 进程或独立 sandboxed_process（com.google.android.webview:sandboxed_process*）。

  主体 HWUI App 带 :sandboxed_process 子进程时，主进程仍是 ANDROID_VIEW_STANDARD_BLAST，子进程才走 Functor。

  '
```

## Detection

```yaml
required_signals:
- thread: RenderThread
  min_count: 1
scoring_signals:
- signal: has_draw_gl
  slice_pattern: '*DrawGL*'
  weight: 25
- signal: has_draw_fn_draw_gl
  slice_pattern: '*DrawFn_DrawGL*'
  weight: 20
- signal: has_draw_functor
  slice_pattern: '*DrawFunctor*'
  weight: 15
- signal: has_cr_renderer
  thread_pattern: CrRendererMain*
  weight: 25
- signal: has_render_thread
  thread_pattern: RenderThread*
  weight: 10
exclude_if:
- thread_pattern: VizCompositorThread*
- thread: 1.ui
```

## Teaching model

```yaml
title: WebView GL Functor 渲染管线
summary: '传统 WebView 渲染模式，WebView 内容通过 GL Functor 机制嵌入到

  App 的 RenderThread 中渲染。browser code 通常仍在宿主 app 进程内，

  App 需要等待 WebView 完成 draw callback，可能拖慢 RenderThread。

  '
mermaid: "sequenceDiagram\n  participant VA as VSync-app\n  participant Main as App (main)\n  participant RT as RenderThread\n\
  \  participant CR as CrRendererMain\n  participant Blink as Blink Engine\n  participant BQ as BufferQueue\n  participant\
  \ VS as VSync-sf\n  participant SF as SurfaceFlinger\n\n  Note over VA,SF: \U0001F4CD WebView GL Functor 模式\n  VA->>Main:\
  \ \U0001F514 VSync-app\n  activate Main\n  Main->>RT: syncFrameState\n  deactivate Main\n\n  activate RT\n  RT->>RT: DrawFrame\
  \ 开始\n  RT->>CR: 调用 WebView draw callback\n  deactivate RT\n\n  activate CR\n  CR->>Blink: 渲染网页内容\n  CR->>CR: GPU 绘制\n \
  \ CR-->>RT: 返回\n  deactivate CR\n\n  activate RT\n  RT->>RT: 继续 DrawFrame\n  RT->>BQ: queueBuffer\n  deactivate RT\n\n \
  \ VS->>SF: \U0001F514 VSync-sf\n  activate SF\n  SF->>SF: latchBuffer\n  SF->>SF: HWC Composite\n  deactivate SF\n\n  Note\
  \ over VA,SF: ⚠️ WebView 阻塞 RenderThread，可能影响流畅度\n"
thread_roles:
- thread: main
  role: WebView 宿主 UI
  description: 承载 WebView 的 Activity/Fragment
- thread: RenderThread
  role: App 渲染
  description: 渲染 App UI，等待 WebView Functor
  trace_tags: DrawFrame, DrawFunctor/DrawGL（是否可见依 tracing 配置）
- thread: CrRendererMain
  role: Chromium 主渲染
  description: WebView/Chromium 内容渲染
  trace_tags: Blink, V8
key_slices:
- name: DrawGL / DrawFn_DrawGL (hint)
  thread: RenderThread
  description: GL Functor 调用提示信号
- name: DrawFunctor (hint)
  thread: RenderThread
  description: Functor 绘制提示信号
- name: Blink
  thread: CrRendererMain
  description: Blink 渲染引擎
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
  description: 'Chromium 网页内容产出的 DDL 在 AwDrawFnImpl::DrawGL/DrawVk 段 replay 到宿主 RT。

    网页内容重时这一段独自就能让宿主 RT 超 budget，外部表现是整页掉帧（不是网页"自己"掉帧）。

    '
  detection_skill: render_thread_slices
- id: chromium_renderer_jank
  name: Chromium Renderer 卡导致网页更新晚
  description: 'CrRendererMain 上 Blink Layout/Paint 重，或 Compositor 线程卡住，导致下一次 functor replay 拿到的 DDL 是旧内容。

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
