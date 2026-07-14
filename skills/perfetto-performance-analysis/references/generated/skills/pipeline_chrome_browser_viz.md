GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/chrome_browser_viz.skill.yaml
Source SHA-256: 466d0a5cad5e8f40b35606a938cb63f3e17c75995c13f5df9629200c8d56b37b
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# Chrome Browser (Viz)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_chrome_browser_viz
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: CHROME_BROWSER_VIZ
display_name: Chrome Browser (Viz)
description: Chrome 浏览器 Viz 合成器管线，多进程架构 (Browser/Renderer/GPU)
icon: web
family: webview
doc_path: rendering_pipelines/S09_webview_type.md
s_article_ref: S09
four_features:
  producer_threads:
  - CrBrowserMain
  - CrRendererMain
  - VizCompositorThread
  - CrGpuMain
  - CompositorTileWorker*
  expected_layer_count: 1
  bufferqueue_path: MULTIPROCESS_CHROMIUM_TO_OUTPUT_SURFACE
  extra_rhythm_sources:
  - chromium_compositor_rhythm
  - viz_display_scheduler
deviation_anchors: multiprocess_chromium_arch_anchor_2_3_4_5_6_at_chromium
difference_from_webview: '与 WEBVIEW_* 区别：

  - Chrome Browser 是独立 App（标准 Chrome 浏览器、Edge、Brave 等），有 CrBrowserMain 主线程

  - WebView 是 Android API 提供的嵌入式组件，运行在宿主 App 进程内（无 CrBrowserMain）

  - Chrome 启用了完整 OOP-R（Out-of-Process Rasterization）+ Viz；WebView 默认不启用 OOP-R

  '
ipc_layers: '多进程通信通过 Mojo IPC（不是 Binder）。Mojo 延迟分析需用 Chromium 自带 trace category。

  '
```

## Detection

```yaml
required_signals:
- thread: VizCompositorThread
  min_count: 1
- thread_pattern: CrBrowserMain*
  min_count: 1
scoring_signals:
- signal: has_viz_compositor_thread
  thread_pattern: VizCompositorThread
  weight: 40
- signal: has_cr_renderer_main
  thread_pattern: CrRendererMain*
  weight: 25
- signal: has_gpu_main
  thread_pattern: CrGpuMain*
  weight: 20
- signal: has_display_scheduler
  slice_pattern: '*DisplayScheduler*'
  weight: 15
- signal: has_begin_frame
  slice_pattern: '*BeginFrame*'
  weight: 10
- signal: has_chromium_compositor
  slice_pattern: '*Chromium.Compositor*'
  weight: 10
exclude_if:
- slice_pattern: '*WebViewChromium*'
- slice_pattern: '*WebView*loadUrl*'
- thread: 1.ui
- thread: 1.raster
- thread: UnityMain
- thread: UnityGfx
```

## Teaching model

```yaml
source: rendering_pipelines/S09_webview_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: viz_scheduling_delay
  name: Viz 调度延迟
  description: VizCompositorThread 合成调度延迟导致掉帧
  detection_skill: sf_frame_consumption
- id: renderer_main_jank
  name: Renderer 主线程卡顿
  description: Blink 引擎 Layout/Paint/JS 执行耗时过长
  detection_skill: jank_frame_detail
- id: gpu_raster_slow
  name: GPU 光栅化慢
  description: OOP-R 光栅化耗时过长
  detection_skill: gpu_analysis
- id: ipc_latency
  name: IPC 延迟
  description: 进程间通信 (Mojo/IPC) 延迟过高
  detection_skill: binder_analysis
- id: cross_process_compositor_frame_aggregation_late
  name: Viz 聚合多个 Renderer CompositorFrame 晚
  description: 'Viz 需要在每个 BeginFrame 周期内聚合所有活跃 Renderer 的 CompositorFrame。

    某个 Renderer 提交晚会让 Viz 这一帧拿到不完整的 frame 集合 — 显示停留旧画面或部分更新。

    '
  detection_skill: sf_frame_consumption
- id: oopr_raster_task_queueing
  name: OOP-R RasterTask 在 GPU 进程排队
  description: '多 Renderer 同时活跃时 RasterTask 都涌入 CrGpuMain，

    队列长会让某些 tile 的光栅化晚到，最终影响 CompositorFrame 完整性。

    '
  detection_skill: gpu_render_in_range
- id: chrome_specific_swap_chain_buffers
  name: Chrome 特有的 swap chain buffer 数（不是 BLASTBufferQueue）
  description: 'Chrome 直接管理 ANativeWindow/swap chain，不走 Android HWUI 的 BLASTBufferQueue 路径。

    分析 buffer 周转时不要套用 BLAST 经验——Chrome 自己的 swap chain 深度由 Viz 决定。

    '
  detection_skill: render_thread_slices
recommended_skills:
- sf_frame_consumption
- cpu_analysis
- gpu_analysis
- binder_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (Chrome 开始生产帧)
- pattern: CrBrowserMain
  match_by: name
  priority: 2
  reason: Chrome Browser 主线程 (导航/UI)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin Chrome Browser 进程的主线程
- pattern: CrRendererMain
  match_by: name
  priority: 3
  reason: Chrome Renderer (Blink 渲染)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染的 Renderer 进程
- pattern: VizCompositorThread
  match_by: name
  priority: 4
  reason: Viz 合成器 (合成/调度)
  smart_filter:
    enabled: true
    description: 仅 Pin Chrome GPU 进程的 Viz 合成器线程
- pattern: CrGpuMain
  match_by: name
  priority: 5
  reason: Chrome GPU 主线程 (光栅化/提交)
  smart_filter:
    enabled: true
    description: 仅 Pin Chrome GPU 进程的主线程
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
