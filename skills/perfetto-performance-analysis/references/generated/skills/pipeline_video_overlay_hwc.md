GENERATED FILE - DO NOT EDIT.
Source: backend/skills/pipelines/video_overlay_hwc.skill.yaml
Source SHA-256: 39a1bcfe778caa41af3ba3a4846e06d6988f55761e0694cd93efde66f042eabd
Source commit: eb4ef81e660fc397c8cabe90ab0b499899931909
# 视频 Overlay (HWC)

This reference is the portable Agent Skill projection of the source definition. Execute SQL with `perfetto_query.py`; bind declared scalar or JSON-array inputs through `--param`, load prerequisites through `--module`, and pass non-empty saved rows from prior steps through `--result`; dotted fields and numeric indexes select saved scalar values. Evaluate conditions and dependent Skill calls in the listed order.

## Overview

```yaml
name: pipeline_video_overlay_hwc
version: '1.0'
type: pipeline_definition
category: rendering
```

## Metadata

```yaml
pipeline_id: VIDEO_OVERLAY_HWC
display_name: 视频 Overlay (HWC)
description: HWC 视频层硬件加速叠加
icon: video
family: specialized
doc_path: rendering_pipelines/S12_video_overlay_hwc_type.md
s_article_ref: S12
four_features:
  producer_threads:
  - media.codec
  - media.swcodec
  - MediaCodec*
  - Codec2 vendor service
  - OMX-worker
  expected_layer_count: 1
  bufferqueue_path: MEDIACODEC_TO_VIDEO_SURFACE_OR_HWC_SIDEBAND
  extra_rhythm_sources:
  - video_codec_pacing
  - av_sync_clock
deviation_anchors: tunneled_skips_anchor_10_or_overlay_anchor_8_to_9
non_primary_note: '此 pipeline_id 已在 NON_PRIMARY_PIPELINE_IDS（renderingPipelineDetectionSkillGenerator.ts:23），

  detection 改动只影响 features list。它属于"实现细节/正交特征"。

  '
subvariants_note: '文章 S12 把 Video Overlay 拆为 3 个子变种：

  - VIDEO_DECODER_SURFACE（非 Tunneled，MediaCodec → Surface → SurfaceView 或 TextureView）

  - VIDEO_DECODER_TEXTUREVIEW（MediaCodec → TextureView，宿主采样）

  - VIDEO_TUNNELED_PLAYBACK（硬件 A/V 同步，sideband stream，App 进程看不到中间过程）

  当前 variant 对应 S12；decoder、TextureView 与 tunneled playback 作为同一类型下的检测子路径输出。

  '
hwc_overlay_decision_factors: 'HWC 5 步谈判（S01）针对视频时关注：

  - buffer 格式（YUV NV12/P010 vs RGBA）

  - DRM/HDCP（必须 secure overlay）

  - overlay plane 数量上限

  - 缩放比例与旋转

  - 色彩空间与 HDR 元数据

  '
```

## Detection

```yaml
scoring_signals:
- signal: has_hwc
  slice_pattern: '*HWC*'
  weight: 20
- signal: has_hardware_composer
  slice_pattern: '*HardwareComposer*'
  weight: 15
- signal: has_video
  slice_pattern: '*Video*'
  weight: 15
- signal: has_mediacodec
  slice_pattern: '*MediaCodec*'
  weight: 20
```

## Teaching model

```yaml
source: rendering_pipelines/S12_video_overlay_hwc_type.md
```

## Analysis guidance

```yaml
common_issues:
- id: decode_stall
  name: 解码延迟
  description: 视频解码器处理延迟
  detection_skill: cpu_analysis
- id: codec_underflow_release_fence
  name: Codec output buffer 不足（release fence 晚回）
  description: 'MediaCodec output pool 用完 → dequeueOutputBuffer 阻塞。

    根因：HWC 没把上一帧 buffer 真正消费（release fence 晚），常因 HWC 降级 client composition 增加延迟。

    '
  detection_skill: present_fence_timing
- id: hwc_overlay_fallback_for_video
  name: HWC 视频层回退 client composition
  description: '视频 overlay 条件不满足（DRM/旋转/缩放/HDR/plane 数量）时回退 client composition。

    SF Duration 抬升 + GPU 带宽吃紧 + 功耗上升 — 这些都是 HWC 决策切换的信号。

    '
  detection_skill: sf_layer_count_in_range
- id: tunneled_invisible_in_app_process
  name: Tunneled 模式 App 进程看不到中间过程
  description: 'Tunneled 下 MediaCodec → HAL sideband stream → HWC，App 进程看不到 releaseOutputBuffer 这种 slice。

    排查问题需要 HAL trace tag + HWC trace tag，App 侧 trace 不完整是正常的。

    '
  detection_skill: cpu_analysis
- id: video_fps_vs_display_fps_mismatch
  name: 视频帧率 vs 显示帧率不匹配
  description: '视频通常 24/30/60 fps，屏幕通常 60/90/120Hz。setFrameRate() API 让 SF 调整 VRR 档位匹配。

    端到端延迟用 present fence 而非 releaseOutputBuffer。

    '
  detection_skill: vsync_alignment_in_range
recommended_skills:
- sf_frame_consumption
- cpu_analysis
- present_fence_timing
- sf_layer_count_in_range
```

## Optional UI metadata

The following auto-pin instructions are SmartPerfetto UI hints. They are optional in a portable agent workflow.

```yaml
instructions:
- pattern: ^VSYNC-app$
  match_by: name
  priority: 1
  reason: VSync (开始生产帧)
- pattern: MediaCodec
  match_by: name
  priority: 2
  reason: 视频解码 (生产)
- pattern: HWC|HardwareComposer
  match_by: name
  priority: 3
  reason: 硬件合成器 (传输/合成)
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
  reason: HWC 合成/显示
  main_thread_only: true
```
