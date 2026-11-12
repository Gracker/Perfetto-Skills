GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/media.strategy.md
Source SHA-256: 3f671d39f4ecc623184bb7ba261d14b49527925e5b5ae3bf64d94de0d505a709

# Media Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

`invoke_skill("<name>", {...})` steps mean: run `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill <name> --output-dir DIR` and pass each object field as `--param NAME=JSON`. Every Skill named this way is an exported, executable portable Skill, and every field is one of its declared inputs.

## Portable execution commands

- List Skills: `python3 <skill-root>/scripts/perfetto_skill.py list`.
- Run a Skill: `python3 <skill-root>/scripts/perfetto_skill.py run TRACE --skill SKILL --output-dir DIR`.
- Run one query: `python3 <skill-root>/scripts/perfetto_query.py TRACE --query-id SKILL/STEP --output RESULT.json`.
- Compare side summaries: `python3 <skill-root>/scripts/perfetto_compare.py --side NAME=SUMMARY.json --baseline NAME`.
- Read and write evidence as ordinary local JSON files; no artifact, session, snapshot, or host-tool API exists.

## Portable strategy metadata

```yaml
scene: media
classification_description: Audio, video and camera pipelines, decoding, playback or capture behavior and performance.
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
- 相机
- 预览
- camera
- preview
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
```

## Investigation methodology

Apply `system_execution` version 2 from [shared investigation methods](investigation-profiles.yaml.md).

Apply `causal_reasoning` version 1 from [shared investigation methods](investigation-profiles.yaml.md).

### media_critical_path (critical_path)

Identify audio, codec, camera, renderer and service tasks and their buffer deadlines. Bind producer/consumer roles across authorized processes; keep each task priority observation separate from actual scheduling policy.

### media_dependencies (dependency_chain)

Follow buffer queue, service/Binder, GPU and display dependencies for underrun or late-frame explanations. Missing scheduler policy is unknown and never proof that RT should be enabled.

#### media Core Strategy

**Route card**: 相机 / 预览 / 视频 / 音频 / 解码 / 编码 / camera / preview / media / codec / video / audio

**Capabilities**: required=[cpu_scheduling], optional=[frame_rendering, gpu, gpu_work_period, power_rails]

**Mandatory aspects**
- media_source_activity: 相机/预览先用 camera_trace_evidence；编解码/播放使用 media_codec_activity。分别检查实际数据源，不能用缺少 codec slices 代替 Camera 取证。
- render_or_power_context: 媒体卡顿/耗电问题需要补充渲染、GPU 或功耗上下文 (requires one of: invoke_skill(gl_standalone_swap_jank), invoke_skill(android_gpu_work_period_track), invoke_skill(power_consumption_overview))

**Phase reminders**
- media_source_activity: 相机/预览先调用 camera_trace_evidence 读取 callback、帧类型、SF 呈现端及SF buffer 关联覆盖；codec 管线调用 media_codec_activity。 工具: camera_trace_evidence, media_codec_activity
- media_rendering_power: 视频/媒体卡顿需要结合 frame/GL/GPU/power 证据：必要时调用 scrolling_analysis、gl_standalone_swap_jank、android_gpu_work_period_track、power_consumption_overview。 工具: media_codec_activity, gl_standalone_swap_jank, android_gpu_work_period_track, power_consumption_overview

**Final report contract summary**
- 遵循通用输出契约。


<!-- strategy-detail id="full" title="media full strategy detail" keywords="media,视频,音频,解码,编码,media,codec,video,audio,decoder,encoder,mediacodec,codec2,媒体 / Codec 分析,detail,full" default="true" -->
#### 媒体 / Codec 分析

按实际媒体管线选择已有的证据生产者；相机预览不依赖 MediaCodec。允许新取证时，优先读取对应 Skill 的全量聚合和覆盖，再对缺口做最小查询。

**Phase 1 — 媒体源与呈现取证：**

相机、Camera2 或预览问题先调用：

```
invoke_skill("camera_trace_evidence", { start_ts: "<start>", end_ts: "<end>" })
```

- `camera_callback_cadence` 是逐进程、逐 source/surface、跨 callback 线程合并的观测到达节奏，不是传感器配置或硬件完成时刻。
- `camera_frame_population` 分开 DisplayFrame / SurfaceFrame 与各自的 UPID、layer、Dropped 和未完成条目。`camera_display_cadence` 只报告 SF DisplayFrame 的 `ts+dur` 呈现端间隔，范围是 SF 进程上下文，不能直接称作相机层。
- `camera_surface_cadence` 和 `camera_buffer_delivery` 只关联完整 SF layer 实例的 latch→commit→DisplayFrame；完整呈现端须在请求窗口内。BLAST queue ID 与 SF layer ID 属于不同域，Skill 不测 app arrival→present；缺少原生 Camera SurfaceFrame 或显式桥接时，不以共同 prefix、相等数字或 nearest timestamp 造逐内容帧关联。编号歧义、跨窗或尾部不完整保持 unavailable。
- `camera_binder_execution` 分开完整同步事务的 wall 与对应 server 线程 Running/状态覆盖。该 Skill 不测传感器预算、在飞行容量、管线深度或 headroom，不能从约一个帧周期的 wall 推出“零余量”。
- 先选与问题对象一致的进程和 surface；这个 trace 级上下文 Skill 不宣称对一个包实施了精确过滤。观测到的 FPS、content vote、SF 标签和间隔分布各有来源，均不提供显式 Camera 配置或锁相故障的证明。

编解码/播放问题使用原有 codec 生产者：

```
invoke_skill("media_codec_activity", { package: "<包名>", start_ts: "<start>", end_ts: "<end>" })
```

重点看 `dequeueInputBuffer` / `queueInputBuffer` / `dequeueOutputBuffer` / `releaseOutputBuffer` 是否出现长耗时，以及 codec 线程是否集中在某个窗口。

**Phase 2 — 渲染/GPU/功耗上下文：**

| 问题 | 调用 |
|---|---|
| 视频掉帧但 codec 正常 | `invoke_skill("gl_standalone_swap_jank")` 或按场景切回 scrolling strategy |
| GPU active region 连续或异常 | `invoke_skill("android_gpu_work_period_track")` |
| 媒体播放耗电 | `invoke_skill("power_consumption_overview")` |

输出时标注实际媒体信号来源与范围。缺 codec slices 只限定 codec 归因；Camera 证据按其独立的 callback、Binder、surface 绑定和显示上下文覆盖判断。缺少某一观测源不等于健康，也不否定其他已观测的节奏变化。
<!-- /strategy-detail -->
