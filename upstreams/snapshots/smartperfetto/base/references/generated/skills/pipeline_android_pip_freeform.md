GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/android_pip_freeform.skill.yaml
Source SHA-256: b33f9deea780ee4e15799d96eb4b84b88cec3e3394e25ce1cff31825a767b12a
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# Android PIP/Freeform

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_android_pip_freeform
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: ANDROID_PIP_FREEFORM
display_name: Android PIP/Freeform
description: 画中画和自由窗口模式，特殊窗口管理与合成
icon: pip
family: surface
doc_path: rendering_pipelines/S06_multi_window_type.md
s_article_ref: S06
four_features:
  producer_threads:
  - main
  - RenderThread
  expected_layer_count: 2+
  bufferqueue_path: BBQ_TRANSACTION_INPROC + WMS_GEOMETRY_TRANSACTION
  extra_rhythm_sources: []
deviation_anchors: wms_resize_geometry_overlay_anchor_8
non_primary_note: '此 pipeline_id 已在代码 NON_PRIMARY_PIPELINE_IDS（renderingPipelineDetectionSkillGenerator.ts:23）中注册，

  不会被选为 primary，只会出现在 features list。

  '
windowing_modes: 'Android 16+ AOSP 把 desktop windowing 写为 OEM 可配置的 freeform multi-window 能力。

  Task 的 windowing mode：FULLSCREEN / MULTI_WINDOW / PINNED / FREEFORM /（Android 11 legacy）SPLIT_SCREEN_PRIMARY/SECONDARY。

  '
subvariants_note: '文章 S06 把多窗口拆为 4 子变种：

  - MULTI_WINDOW_SAME_PROCESS（Dialog/PopupWindow/Activity Embedding）

  - MULTI_WINDOW_SPLIT_SCREEN

  - MULTI_WINDOW_PIP（当前 ID 部分覆盖）

  - MULTI_WINDOW_FREEFORM（当前 ID 部分覆盖）

  当前条目在 catalog 中作为 S06 的全局 feature；PIP 与 Freeform 是检测子路径，

  不覆盖宿主应用的主渲染类型。

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_enter_pip_api
  slice_pattern: '*enterPictureInPictureMode*'
  weight: 50
- signal: has_pip_marker
  slice_pattern: '*PictureInPicture*'
  weight: 50
- signal: has_wms_resize_task
  slice_pattern: '*WMS.resizeTask*'
  weight: 50
```

## Teaching model

```yaml
source: rendering_pipelines/S06_multi_window_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: pip_animation_jank
  name: PIP 动画卡顿
  description: PIP 进入/退出动画期间帧率下降
  detection_skill: jank_frame_detail
- id: pip_resize_slow
  name: 窗口缩放延迟
  description: PIP 窗口尺寸变化时渲染延迟
  detection_skill: render_thread_slices
- id: freeform_bounds_update
  name: Freeform 边界更新慢
  description: 拖动 Freeform 窗口时响应延迟
  detection_skill: app_frame_production
- id: syncgroup_geometry_buffer_alignment
  name: 几何与 buffer 没同帧生效（缺 SurfaceSyncGroup）
  description: 'PIP 进入/退出、Freeform resize 时窗口几何变化与 buffer 更新若不同帧生效，会出现"窗口已是新尺寸但内容还是旧 buffer"或"内容已新但位置还是旧"的错位。

    Android 14+ 公开的 SurfaceSyncGroup（API 34）可让受控 SurfaceControl/SurfaceView 几何与 buffer 同帧生效；

    Android 13 内部的 SurfaceSyncer 也提供类似能力。S06 §"几何变化与内容更新要同帧生效"。

    '
  detection_skill: sf_composition_in_range
- id: hwc_plane_limit_with_more_windows
  name: PIP 增加同屏 layer 数挤占 HWC plane
  description: 'PIP 与主窗口同屏时活跃 layer 数增加，超出 HWC overlay plane 上限或不满足约束（透明/旋转/HDR）的 layer 会回退到 client composition，

    GPU 合成成本和带宽抬升。S06 §"HWC 的组合题在多窗口里更复杂"。

    '
  detection_skill: sf_layer_count_in_range
- id: shell_transition_animation_overhead
  name: Shell transition 动画开销
  description: 'Android 13+ Shell transition（WMShell + sync）重做了 PIP/Freeform 进入/退出动画的协调机制。

    转场期间 Shell 进程、SystemUI 进程和应用进程都参与；trace 上看到 SystemUI/Shell 相关动画 slice 是常态。

    '
  detection_skill: sf_frame_consumption
recommended_skills:
- sf_frame_consumption
- jank_frame_detail
- render_thread_slices
- app_frame_production
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
  reason: PIP 控制逻辑 (生产)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的主线程（避免 pin 到系统/其他 app 的 main）
- pattern: ^RenderThread(\s+\d+)?$
  match_by: name
  priority: 3
  reason: 窗口渲染 (传输)
  expand: true
  smart_filter:
    enabled: true
    description: 仅 Pin 活跃渲染进程的 RenderThread（若为纯 SurfaceView/游戏则可能为空）
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
  reason: PIP 层合成/显示
  main_thread_only: true
```
