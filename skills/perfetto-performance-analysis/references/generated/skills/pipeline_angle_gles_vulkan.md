GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/angle_gles_vulkan.skill.yaml
Source SHA-256: 6534fbaf27524e1bb36aaa99335afadba617e5be071cd201e34b740930b94b02
Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb
# ANGLE (GLES over Vulkan)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_angle_gles_vulkan
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANGLE_GLES_VULKAN
display_name: ANGLE (GLES over Vulkan)
description: 通过 ANGLE 将 OpenGL ES 翻译为 Vulkan
icon: translate
family: graphics
doc_path: rendering_pipelines/S08_native_graphics_type.md
s_article_ref: S08
four_features:
  producer_threads:
  - GLThread
  - RenderThread
  - any custom
  expected_layer_count: 1
  bufferqueue_path: ANATIVEWINDOW_VULKAN_SWAPCHAIN_VIA_ANGLE
  extra_rhythm_sources: []
deviation_anchors: translation_layer_anchor_4_5_6
non_primary_note: '此 pipeline_id 已在代码 NON_PRIMARY_PIPELINE_IDS 中（renderingPipelineDetectionSkillGenerator.ts:23），

  不会被选为 primary，只出现在 features list。它属于"实现细节/正交特征"，与 OPENGL_ES / VULKAN_NATIVE 的 primary 选择并不冲突。

  '
ecosystem_note: 'Android 生态中 ANGLE 常由 Chromium / WebView / 自研内核启用；游戏引擎也可能直接集成。

  Android 15+ 对 ANGLE 的支持提升，但是否默认启用仍依设备和 OEM 策略。

  '
```

## Detection

```yaml
required_signals:
- slice_pattern: '*vkQueuePresentKHR*'
  min_count: 1
scoring_signals:
- signal: has_angle
  slice_pattern: '*ANGLE*'
  weight: 80
```

## Teaching model

```yaml
source: rendering_pipelines/S08_native_graphics_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: angle_overhead
  name: ANGLE 翻译开销
  description: API 翻译层的 CPU 开销
  detection_skill: cpu_analysis
- id: angle_validation_overhead
  name: ANGLE GLES 状态验证开销
  description: 'ANGLE 需要把 GLES 状态机映射到 Vulkan 的显式状态对象（pipeline、descriptor set、render pass 等），

    每次 GLES 调用都涉及状态验证。状态变化频繁的应用 CPU 开销显著。

    '
  detection_skill: cpu_analysis
- id: dual_layer_slices_visible
  name: trace 同时出现 GLES + Vulkan slice 是 ANGLE 标志
  description: '在同一进程同时看到 glDraw* / eglSwapBuffers（应用层）和 vkCmdDraw* / vkQueuePresentKHR（ANGLE 后端）

    是该 pipeline 的决定性信号。仅看到 GLES 而无 Vulkan 痕迹更可能是 GLES 原生或 ANGLE 的 OpenGL 后端。

    '
  detection_skill: gpu_analysis
recommended_skills:
- gpu_analysis
- cpu_analysis
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
  reason: 应用逻辑 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程
- pattern: ^RenderThread(\s+\d+)?$|GLThread|ANGLE|Vulkan|Vk
  match_by: name
  priority: 3
  reason: ANGLE 翻译层 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的渲染/翻译线程
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
