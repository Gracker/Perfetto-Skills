GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/webview_textureview_custom.skill.yaml
Source SHA-256: 6c771335298179b05c20755f8c7716f9296836a061b73eab41a3d78467d5e36d
Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee
# WebView TextureView (定制内核)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_webview_textureview_custom
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: WEBVIEW_TEXTUREVIEW_CUSTOM
display_name: WebView TextureView (定制内核)
description: X5/UC 等定制 WebView 内核，使用 TextureView
icon: web
family: webview
doc_path: rendering_pipelines/S09_webview_type.md
s_article_ref: S09
four_features:
  producer_threads:
  - WebViewCore
  - X5*
  - UCCore*
  - TBS*
  consumer_threads:
  - RenderThread
  expected_layer_count: 1
  bufferqueue_path: CUSTOM_KERNEL_TO_SURFACETEXTURE_TO_HOST_BBQ
  extra_rhythm_sources:
  - custom_kernel_rhythm
deviation_anchors: custom_kernel_to_host_resample_anchor_5
custom_kernels: '国内常见定制内核：

  - 腾讯 X5 / TBS（QQ、微信、QQ 浏览器）

  - 阿里 UCCore（UC 浏览器、夸克、支付宝）

  - 百度 ZeusCore（百度 App）

  '
subvariants_note: 文章 S09 列出的 5 种 WebView 路径之一（参 webview_gl_functor 注释）。
```

## Detection

```yaml
scoring_signals:
- signal: has_tbs
  slice_pattern: '*TBS*'
  weight: 30
- signal: has_x5
  slice_pattern: '*X5*'
  weight: 30
- signal: has_uccore
  slice_pattern: '*UCCore*'
  weight: 20
exclude_if:
- thread: 1.ui
```

## Teaching model

```yaml
source: rendering_pipelines/S09_webview_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: custom_kernel_invisible_to_aosp_optimizations
  name: AOSP 优化对定制内核失效
  description: 'AOSP WebView 优化（OOP-R / Viz / SurfaceControl）仅适用于 stock WebView。

    X5/UC/TBS 等定制内核不走这些路径，性能特征与 stock 完全不同——分析时不要套用 stock 经验。

    '
  detection_skill: cpu_analysis
- id: textureview_resample_overhead
  name: 宿主 RT updateTexImage + GPU 重采样开销
  description: '定制内核走 TextureView 路径，所有 S04 TextureView 的代价都适用：updateTexImage acquire、

    GPU 重采样、YUV→RGB 色彩转换、acquire/release 双层 fence。

    '
  detection_skill: gpu_render_in_range
- id: kernel_thread_naming_unstable
  name: 定制内核线程名不稳定
  description: 'X5/UC/TBS 定制内核的线程名随版本变化大（X5_GLBackbufferThread / TbsRenderThread / UCRenderingThread 等）。

    Trace 中识别需要交叉用 process name + slice 名 pattern。

    '
  detection_skill: cpu_analysis
recommended_skills:
- render_thread_slices
- cpu_analysis
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
  reason: UI 集成 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的宿主主线程
- pattern: CrRendererMain|WebViewCore|UCCore|X5
  match_by: name
  priority: 3
  reason: 定制内核渲染 (生产/传输)
  smart_filter:
    enabled: true
    description: 仅 Pin 属于当前 app 的内核进程/线程（多 app trace 下减少噪音）
- pattern: SurfaceTexture|updateTexImage|onFrameAvailable
  match_by: name
  priority: 3.5
  reason: SurfaceTexture (纹理生产-消费/出图关键)
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 4
  reason: 纹理合成 (传输)
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
