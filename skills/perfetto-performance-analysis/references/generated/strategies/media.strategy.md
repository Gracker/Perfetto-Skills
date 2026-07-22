GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/media.strategy.md
Source SHA-256: 37933ba751d32e489cce31bcecd04b5566e1c1b5944b85c01f30c08df29c9ec5
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

# Media Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: media
priority: 6
effort: medium
required_capabilities:
- cpu_scheduling
optional_capabilities:
- frame_rendering
- gpu
- gpu_work_period
- power_rails
keywords:
- 视频
- 音频
- 解码
- 编码
- media
- codec
- video
- audio
- decoder
- encoder
- mediacodec
- codec2
- omx
compound_patterns:
- (视频|音频|解码|编码).*(卡顿|耗电|延迟|掉帧)
- (media|video|audio|codec|decoder).*(jank|power|latency|stutter)
phase_hints:
- id: codec_activity
  keywords:
  - MediaCodec
  - Codec2
  - OMX
  - decoder
  - encoder
  - 解码
  - 编码
  - 视频卡顿
  constraints: 优先调用 media_codec_activity 检查 codec/buffer 事件。该 skill 基于 slice 信号；缺 codec trace 时必须标注数据不足。
  critical_tools:
  - media_codec_activity
  critical: true
- id: media_rendering_power
  keywords:
  - frame
  - gpu
  - power
  - 掉帧
  - 功耗
  - work period
  constraints: 视频/媒体卡顿需要结合 frame/GL/GPU/power 证据：必要时调用 scrolling_analysis、gl_standalone_swap_jank、android_gpu_work_period_track、power_consumption_overview。
  critical_tools:
  - media_codec_activity
  - gl_standalone_swap_jank
  - android_gpu_work_period_track
  - power_consumption_overview
  critical: false
plan_template:
  mandatory_aspects:
  - id: codec_activity
    match_keywords:
    - media_codec_activity
    - MediaCodec
    - Codec2
    - OMX
    - 解码
    - 编码
    suggestion: 媒体场景必须检查 codec/buffer 活动或明确说明 trace 缺少媒体信号
    required_expected_calls:
    - skill_id: media_codec_activity
  - id: render_or_power_context
    match_keywords:
    - gl_standalone_swap_jank
    - android_gpu_work_period_track
    - power_consumption_overview
    - frame
    - gpu
    - 功耗
    suggestion: 媒体卡顿/耗电问题需要补充渲染、GPU 或功耗上下文
    required_expected_call_alternatives:
    - skill_id: gl_standalone_swap_jank
    - skill_id: android_gpu_work_period_track
    - skill_id: power_consumption_overview
```

#### media Core Strategy

**Route card**: 视频 / 音频 / 解码 / 编码 / media / codec / video / audio / decoder / encoder

**Capabilities**: required=[cpu_scheduling], optional=[frame_rendering, gpu, gpu_work_period, power_rails]

**Phase reminders**
- codec_activity: 优先调用 media_codec_activity 检查 codec/buffer 事件。该 skill 基于 slice 信号；缺 codec trace 时必须标注数据不足。 工具: media_codec_activity
- media_rendering_power: 视频/媒体卡顿需要结合 frame/GL/GPU/power 证据：必要时调用 scrolling_analysis、gl_standalone_swap_jank、android_gpu_work_period_track、power_consumption_overview。 工具: media_codec_activity, gl_standalone_swap_jank, android_gpu_work_period_track, power_consumption_overview

**Final report contract summary**
- 遵循通用输出契约。


<!-- strategy-detail id="full" title="media full strategy detail" keywords="media,视频,音频,解码,编码,media,codec,video,audio,decoder,encoder,mediacodec,codec2,媒体 / Codec 分析,detail,full" default="true" -->
#### 媒体 / Codec 分析

当前公开 stdlib index 没有稳定的 Android codec 专用表，因此媒体基础分析先基于 `slice` / `thread` 信号识别 MediaCodec、Codec2、OMX、CCodec 和 buffer API。

**Phase 1 — Codec 活动与慢事件：**


重点看 `dequeueInputBuffer` / `queueInputBuffer` / `dequeueOutputBuffer` / `releaseOutputBuffer` 是否出现长耗时，以及 codec 线程是否集中在某个窗口。

**Phase 2 — 渲染/GPU/功耗上下文：**

输出时必须标注媒体 trace 信号来源。如果 codec slices 不存在，只能说明当前 trace 不支持媒体归因，并给出采集建议。
<!-- /strategy-detail -->
