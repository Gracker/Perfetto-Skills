GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/media.strategy.md
Source SHA-256: 37933ba751d32e489cce31bcecd04b5566e1c1b5944b85c01f30c08df29c9ec5
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Media Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### media Core Strategy

**Route card**: 视频 / 音频 / 解码 / 编码 / media / codec / video / audio / decoder / encoder

**Capabilities**: required=[cpu_scheduling], optional=[frame_rendering, gpu, gpu_work_period, power_rails]





**Phase reminders**
- codec_activity: 优先调用 media_codec_activity 检查 codec/buffer 事件。该 skill 基于 slice 信号；缺 codec trace 时必须标注数据不足。 工具: media_codec_activity
- media_rendering_power: 视频/媒体卡顿需要结合 frame/GL/GPU/power 证据：必要时调用 scrolling_analysis、gl_standalone_swap_jank、android_gpu_work_period_track、power_consumption_overview。 工具: media_codec_activity, gl_standalone_swap_jank, android_gpu_work_period_track, power_consumption_overview

**Final report contract summary**
- 遵循通用输出契约。


**Detail ref**
- `media:full`: 媒体 / Codec 分析 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="media full strategy detail" keywords="media,视频,音频,解码,编码,media,codec,video,audio,decoder,encoder,mediacodec,codec2,媒体 / Codec 分析,detail,full" default="true" -->
#### 媒体 / Codec 分析

当前公开 stdlib index 没有稳定的 Android codec 专用表，因此媒体基础分析先基于 `slice` / `thread` 信号识别 MediaCodec、Codec2、OMX、CCodec 和 buffer API。

**Phase 1 — Codec 活动与慢事件：**



重点看 `dequeueInputBuffer` / `queueInputBuffer` / `dequeueOutputBuffer` / `releaseOutputBuffer` 是否出现长耗时，以及 codec 线程是否集中在某个窗口。

**Phase 2 — 渲染/GPU/功耗上下文：**



输出时必须标注媒体 trace 信号来源。如果 codec slices 不存在，只能说明当前 trace 不支持媒体归因，并给出采集建议。
<!-- /strategy-detail -->
