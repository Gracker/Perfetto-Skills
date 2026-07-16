GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/software_compositing.skill.yaml
Source SHA-256: b33f5c40a40d7c5e8b7331bd420c27d8ddd50beb248469018ecfd156b425d78f
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 软件合成回退

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_software_compositing
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: SOFTWARE_COMPOSITING
display_name: 软件合成回退
description: SurfaceFlinger CPU 软件合成回退，GPU 合成不可用时的降级路径
icon: memory
family: surfaceflinger
doc_path: rendering_pipelines/S01_rendering_types_overview.md
s_article_ref: S01
four_features:
  producer_threads: []
  consumer_threads:
  - SurfaceFlinger
  expected_layer_count: any
  bufferqueue_path: SF_CLIENT_COMPOSITION
  extra_rhythm_sources: []
deviation_anchors: anchor_10_client_composition_when_hwc_rejects
difference_from_android_view_software: 'ANDROID_VIEW_SOFTWARE：应用侧 CPU Skia 绘制（lockCanvas/unlockCanvasAndPost），无 RenderThread。

  SOFTWARE_COMPOSITING：SF 侧 client composition（HWC 把 layer 打回 SF GPU 合成）。

  两者都叫"软件"但本质不同：前者是 Producer 路径，后者是 Consumer 合成路径。

  '
hwc_fallback_triggers: 'HWC 把 layer 从 DEVICE 降级到 CLIENT（S01 5 步谈判）的常见原因：

  - 透明混合（alpha < 1.0 且复杂遮挡关系）

  - 旋转或缩放超 HWC 能力

  - overlay plane 数量不足（同屏 layer > HWC plane 上限）

  - 受保护内容路径（DRM/HDCP）

  - 色彩空间或 HDR 元数据不支持

  - HWC 自身不支持的混合模式

  '
```

## Detection

```yaml
required_signals:
- thread: SurfaceFlinger
  min_count: 1
scoring_signals:
- signal: has_handle_message_refresh
  slice_pattern: '*handleMessageRefresh*'
  weight: 30
- signal: has_sf_commit
  slice_pattern: '*commit*'
  weight: 15
- signal: has_sf_composite
  slice_pattern: '*composite*'
  weight: 15
- signal: has_validate_display
  slice_pattern: '*validateDisplay*'
  weight: 20
- signal: has_present_display
  slice_pattern: '*presentDisplay*'
  weight: 20
exclude_if:
- slice_pattern: GPU completion*
- slice_pattern: '*eglSwapBuffers*'
```

## Teaching model

```yaml
source: rendering_pipelines/S01_rendering_types_overview.md
```

## Analysis guidance

```yaml
common_issues:
- id: sf_cpu_compositing_overhead
  name: CPU 合成开销过大
  description: SurfaceFlinger 回退到 CPU 合成导致主线程耗时增加
  detection_skill: sf_composition_in_range
- id: hwc_layer_overflow
  name: HWC 叠加层溢出
  description: Layer 数量超过硬件叠加层上限，触发 Client 合成
  detection_skill: surfaceflinger_analysis
- id: client_composition_increases_gpu_load
  name: Client composition 加重 SF GPU 负担
  description: 'HWC 拒绝某 layer 后 SF 用 GPU 合成到 client target buffer，再交回 HWC present。

    这一段 GPU 工作完全压在 SF 进程，挤占 game/video/UI 应用自己的 GPU 预算 — 多 layer 场景尤其明显。

    '
  detection_skill: gpu_render_in_range
- id: hwc_decision_oscillation
  name: HWC 决策反复抖动
  description: '相邻几帧 layer 几何/可见性变化频繁时 HWC 重新评估，

    device ↔ client 合成方式来回切换会造成功耗和延迟周期性抬升。

    S05 §"功耗上涨、带宽突然变高、偶发卡顿，常常发生在这种策略切换附近"。

    '
  detection_skill: sf_layer_count_in_range
- id: hwc_secure_composition_path
  name: DRM/HDCP 强制 secure overlay 路径
  description: '受保护内容（GRALLOC_USAGE_PROTECTED）必须走 secure overlay 或 secure composition 路径。

    路径错（例如 TextureView 走 HWUI 普通 GPU context 读 protected buffer）→ 黑屏或拒绝播放。

    '
  detection_skill: surfaceflinger_analysis
recommended_skills:
- sf_composition_in_range
- surfaceflinger_analysis
- cpu_analysis
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-sf$
  match_by: name
  priority: 1
  reason: VSync (SurfaceFlinger 合成触发)
- pattern: ^[sS]urface[fF]linger
  match_by: name
  priority: 2
  reason: SurfaceFlinger (软件合成执行)
  main_thread_only: true
  expand: true
  smart_filter:
    enabled: true
    description: Pin SurfaceFlinger 主线程以观察 CPU 合成耗时
- pattern: ^VSYNC-app$
  match_by: name
  priority: 3
  reason: VSync (App 帧生产参考)
```
