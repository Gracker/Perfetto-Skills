GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/rn_skia.skill.yaml
Source SHA-256: cc6054986f7d91d0ab0ac819f5d11f251211ddb9db5cb83932fcdef678eb74de
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00
# React Native Skia (@shopify/react-native-skia)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_rn_skia
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: RN_SKIA_RENDERER
display_name: React Native Skia (@shopify/react-native-skia)
description: RN + Skia 自绘渲染，绕过 HWUI 直接用 Skia 在 GPU 上画
icon: react
family: webview
doc_path: rendering_pipelines/rn_skia.md
s_article_ref: S14
four_features:
  producer_threads:
  - mqt_js
  - Skia render thread
  expected_layer_count: 1
  bufferqueue_path: JSI_TO_SKIA_DRAW_TO_SURFACE_BBQ
  extra_rhythm_sources:
  - jsi_synchronous_call
  - skia_render_loop
deviation_anchors: rn_skia_self_draw_anchor_5_at_skia_thread
related_pipelines: '与 NATIVE_GRAPHICS (S08 OPENGL_ES/VULKAN_NATIVE) 的代价模型相似——

  都是应用自绘到独立 Surface，绕过 HWUI。

  '
use_cases: '典型使用场景：

  - 复杂自定义动画（@shopify/react-native-skia + Reanimated）

  - 高性能图形效果（shader / blend mode / 路径动画）

  - 游戏 / 数据可视化

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_mqt_js
  thread_pattern: mqt_js*
  weight: 30
- signal: has_skia_renderer
  slice_pattern: '*SkiaRenderer*'
  weight: 25
- signal: has_skia_picture
  slice_pattern: '*SkiaPicture*'
  weight: 20
- signal: has_react_native_skia
  slice_pattern: '*react-native-skia*'
  weight: 25
- signal: has_skia_paint
  slice_pattern: '*SkPaint*'
  weight: 10
- signal: has_skia_canvas
  slice_pattern: '*SkCanvas*'
  weight: 10
exclude_if:
- slice_pattern: '*FabricUIManager*'
- thread_pattern: mqt_shadow*
- slice_pattern: '*EntityPass*'
```

## Teaching model

```yaml
title: React Native Skia 渲染管线
summary: '@shopify/react-native-skia 提供 RN 直接调用 Skia 自绘的能力：

  - JS 通过 JSI 调用 Skia C++ API

  - Skia 自己有渲染线程，绕过 HWUI RenderThread

  - 输出到独立 Surface 或 TextureView

  - 适用于复杂动画、shader、路径效果


  与 NATIVE_GRAPHICS (S08) 代价模型相似：应用自绘 + GPU fence + Surface BufferQueue。

  '
key_slices:
- name: SkiaRenderer / SkiaPicture
  thread: any
  description: Skia 渲染相关 slice
- name: react-native-skia
  thread: any
  description: react-native-skia 库相关调用
```

## Analysis guidance

```yaml
common_issues:
- id: skia_draw_overhead
  name: Skia 绘制开销
  description: '复杂 path / shader / blend mode 让 Skia draw 阶段耗时膨胀。

    与 S08 OpenGL/Vulkan 路径相似——可能受 GPU bound 限制。

    '
  detection_skill: gpu_analysis
- id: jsi_sync_call_blocking_js
  name: JSI 同步调用阻塞 JS 线程
  description: 'Skia API 经 JSI 同步调用，JS 线程等 Skia 完成。

    高频调用累积让 JS 线程也变重。

    '
  detection_skill: cpu_analysis
- id: gpu_fence_wait
  name: GPU fence 等待
  description: 'Skia 输出 Surface 的 acquire fence 等 GPU 写完。

    与 NATIVE_GRAPHICS (S08) 完全相同。

    '
  detection_skill: present_fence_timing
recommended_skills:
- gpu_analysis
- cpu_analysis
- present_fence_timing
```
