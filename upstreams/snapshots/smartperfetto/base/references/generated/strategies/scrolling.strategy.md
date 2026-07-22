GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scrolling.strategy.md
Source SHA-256: e4b6c20093cb77a04b4dfcfc602539cdbd8b1001927eca76b6670cac4c974c82
Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

# Scrolling Strategy

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
scene: scrolling
priority: 3
effort: medium
required_capabilities:
- frame_rendering
- cpu_scheduling
optional_capabilities:
- binder_ipc
- gpu
- thermal_throttling
- input_latency
- lock_contention
- gpu_work_period
- cpu_freq_idle
- battery_counters
- chrome_scroll_jank
keywords:
- 滑动
- 卡顿
- 掉帧
- 丢帧
- jank
- scroll
- fps
- 列表
- 流畅
- fling
- swipe
- 滚动
- recycler
- recyclerview
- scrollview
- scrollstate
- lazycolumn
- lazyrow
- listview
- lazy
- 快滑
- 慢滑
- stuttering
- frame drop
- frame drops
- dropped frame
- dropped frames
- resync
- resynced
- App Resynced Jitter
- janky
- 不流畅
- impeller
- textureview
- react native
- glsurfaceview
- nativeactivity
- drawfunctor
final_report_contract:
  required_sections:
  - id: root_cause_distribution
    label: 全帧根因分布
    description: 按 reason_code / 责任方聚合，列出帧数、占比、关键四象限或频率特征。
    pattern_groups:
    - - 全帧根因分布
      - 根因分布
      - root[-\s]?cause distribution
      - reason_code
    - - 帧数
      - 占比
      - frame count
      - percentage
      - \|\s*根因\s*\|
      - \|\s*reason
  - id: representative_frames
    label: 代表帧分析
    description: 每个 CRITICAL/HIGH 根因至少给出 1 个代表样本，包含帧耗时、超预算倍数、vsync_missed、关键 slice/阻塞点和因果链。
    pattern_groups:
    - - 代表帧
      - representative\s+frame
    - - frame_id
      - guilty[_ ]?frame
      - 帧耗时
      - 耗时\s*/\s*预算
      - 帧\s*\d+
      - frame duration
    - - vsync_missed
      - VSync\s*丢失
      - 丢失\s*\d+\s*VSync
      - 超预算
      - 预算
      - budget overrun
      - missed[-\s]?vsync
  - id: peak_and_semantic_metrics
    label: 峰值/口径指标
    description: 说明总帧数、真实掉帧、假阳性/Buffer Stuffing、最长帧和最长连续丢帧等口径。
    recovery_text:
      zh:
      - 真实掉帧口径：以以下已完成阶段中确认的用户可感知卡顿为准；仅在阶段证据明确区分时排除假阳性/Buffer Stuffing，否则保留为口径限制。
      - 最长帧/峰值口径：以下阶段证据中的最长单帧与最长连续丢帧代表当前采集窗口峰值；缺失项保持为数据缺口。
      en:
      - 'Real jank semantics: use user-visible jank confirmed by the completed phases below; exclude false positives or Buffer
        Stuffing only when the phase evidence distinguishes them, otherwise keep that boundary as a limitation.'
      - 'Longest frame / peak semantics: the longest single frame and longest consecutive missed-frame interval in the phase
        evidence below represent the current capture-window peak; keep missing fields as data gaps.'
    pattern_groups:
    - - 真实掉帧
      - real[_\s-]?jank
    - - 最长帧
      - longest frame
      - 峰值
  - id: case_recommendations
    label: 相似案例引用
    description: 当 typed caseRecommendations 中存在 strong 匹配时，报告需引用对应 case_id，并说明它是证据验证后的相似案例。
    trigger_patterns:
    - case recommendation|caseRecommendations|相似案例|案例引用
    pattern_groups:
    - - case_id
      - 相似案例
      - 案例引用
      - case recommendation
      - case[-\s]?based
phase_hints:
- id: overview
  keywords:
  - 概览
  - overview
  - 帧
  - frame
  - jank
  - 卡顿
  - scrolling_analysis
  - 统计
  constraints: 必须调用 scrolling_analysis 获取全帧统计。注意区分 buffer_stuffing（非真实掉帧）和感知掉帧。
  critical_tools:
  - scrolling_analysis
  critical: false
- id: root_cause_drill
  keywords:
  - 根因
  - root cause
  - 诊断
  - diagnos
  - 深钻
  - deep
  - drill
  - 代表帧
  - representative
  - 逐帧
  constraints: 对占比 >15% 且绝对帧数 >3 的 reason_code，必须选最严重帧执行 jank_frame_detail/frame_blocking_calls/blocking_chain_analysis 深钻。禁止仅靠
    batch_frame_root_cause 统计分类直接出结论。workload_heavy 必须最后兜底。
  critical_tools:
  - jank_frame_detail
  - frame_blocking_calls
  - blocking_chain_analysis
  critical: true
- id: frame_metrics_overlay
  keywords:
  - overrun
  - per_frame
  - ui time
  - cpu time
  - work period
  - mali
  - 帧内
  - 帧阻塞
  - 阻塞调用
  - Binder
  - futex
  - GPU
  - 功耗
  - 频率
  constraints: 需要帧内 CPU/UI/GPU/阻塞调用细分时，优先用 frame_overrun_summary、cpu_time_per_frame、frame_ui_time_breakdown、frame_blocking_calls、android_gpu_work_period_track、mali_gpu_power_state
    作为补充证据。缺 gpu_work_period 时必须标注数据不足。
  critical_tools:
  - frame_overrun_summary
  - cpu_time_per_frame
  - frame_ui_time_breakdown
  - frame_blocking_calls
  - android_gpu_work_period_track
  - mali_gpu_power_state
  critical: false
- id: missing_frame_gap
  keywords:
  - 缺帧
  - gap
  - frame_production_gap
  - 帧间
  - production gap
  - 隐形缺帧
  constraints: 只有满足缺帧触发条件时才调用 frame_production_gap；如果 real_jank_count 足够、Buffer Stuffing 假阳性低且非 WebView/SurfaceTexture，要记录触发条件并跳过，不要重复要求
    scrolling_analysis。
  critical_tools:
  - frame_production_gap
  critical: false
- id: chrome_scroll_jank
  keywords:
  - Chrome
  - Chromium
  - WebView
  - scroll jank v4
  - preferred frame timeline
  - ChromeScrollJank
  constraints: 当 trace 明确来自 Chrome/Chromium/WebView 或用户提到 Chrome scroll jank 时，调用 chrome_scroll_jank_frame_timeline。若返回 no_chrome_scroll_data，只能说明缺少
    Chrome scroll instrumentation，不要把 Android app FrameTimeline 当作 Chrome scroll jank 证据。
  critical_tools:
  - chrome_scroll_jank_frame_timeline
  critical: false
- id: architecture_specific_jank
  keywords:
  - TextureView
  - SurfaceTexture
  - WebView
  - DrawFunctor
  - React Native
  - RN
  - Fabric
  - JSI
  - GLSurfaceView
  - NativeActivity
  - OpenGL
  - Compose
  - Flutter
  - mixed
  - 混合
  - 架构
  - 生产端
  critical_tools:
  - scrolling_analysis
  - flutter_scrolling_analysis
  - textureview_producer_frame_timing
  - webview_drawfunctor_jank_chain
  - rn_bridge_to_frame_jank
  - rn_fabric_render_jank
  - gl_standalone_swap_jank
  - compose_recomposition_hotspot
  - surfaceflinger_analysis
  critical: false
- id: display_pipeline_boundary
  keywords:
  - BufferQueue
  - BLAST
  - dequeueBuffer
  - queueBuffer
  - SurfaceFlinger
  - HWC
  - acquire fence
  - present fence
  - release fence
  - refresh rate
  - 刷新率
  - ARR
  - VRR
  - FrameTimeline
  - sf_backpressure
  - gpu_fence_wait
  - resync
  - resynced
  - App Resynced Jitter
  constraints: 当掉帧证据涉及 BufferQueue、Fence、SF/HWC、Buffer Stuffing、隐形掉帧或刷新率变化时，必须把 App/RenderThread、BufferQueue queue/dequeue/latch、SF
    commit/composite/present、HWC/display 与 acquire/present/release fence 拆开。queueBuffer 快不等于已上屏；dequeueBuffer 等待更接近 release
    fence/backpressure；刷新率/ARR/VRR 要用实际 VSync 周期，不默认 16.6ms。
  critical_tools:
  - surfaceflinger_analysis
  - buffer_transaction_lifecycle
  - fence_wait_decomposition
  - present_fence_timing
  - vsync_config
  critical: false
- id: resync_sf_backlog
  keywords:
  - resync
  - resynced
  - App Resynced Jitter
  - Choreographer#doFrame - resynced
  - SF没合成
  - 没有合成
  - 后面针堆积
  - 帧堆积
  - backlog
  constraints: 命中 Choreographer#doFrame - resynced 或 App Resynced Jitter 时，先把它当作 Choreographer 因回调迟到/相位漂移而切到后续 VSync 的 marker，不要当作独立
    doFrame 或普通业务耗时重复计数。必须继续核对 FrameTimeline 的 jank_type、present_type、vsync_resynced_jitter_millis、同 layer display/surface
    frame token 连续性、present_ts 间隔和 SF actual/display frame；只有存在 SF actual frame 缺失/late、SF jank_type、present gap 或 dropped
    display frame 证据时，才能说 SF 未合成对应帧。否则按 App resync/jitter、BufferQueue 背压或 App 未按时产帧描述，并说明 SF 结论证据不足。
  critical_tools:
  - scrolling_analysis
  - jank_frame_detail
  - consumer_jank_detection
  - frame_production_gap
  - surfaceflinger_analysis
  critical: true
- id: conclusion
  keywords:
  - 结论
  - conclusion
  - 输出
  - output
  - 报告
  - report
  - 总结
  constraints: 输出必须包含：全帧根因分布表（按 reason_code 聚合）+ 代表帧分析（含四象限+频率+根因推理链）+ 按优先级排序的优化建议。每个 CRITICAL/HIGH 必须有量化证据+因果链。若深钻证据纠正了 batch
    reason_code（例如 lock_binder_wait 但 binder_overlap_ms=0，render_slices_json 指向 cache_miss/makePipeline/shader 编译），最终结论必须使用纠正后的根因命名，并明确标注原
    reason_code 为误分类。
  critical_tools: []
  critical: false
plan_template:
  mandatory_aspects:
  - id: frame_jank_analysis
    match_keywords:
    - frame
    - jank
    - scroll
    - 帧
    - 卡顿
    - 滑动
    - scrolling_analysis
    - consumer_jank
    suggestion: 滑动场景建议包含帧渲染/卡顿分析阶段 (scrolling_analysis, consumer_jank_detection)
    required_expected_calls:
    - skill_id: scrolling_analysis
  - id: frame_artifact_fetch
    match_keywords:
    - batch_frame_root_cause
    - artifact
    - 全帧根因分布
    - 代表帧
    - reason_code
    suggestion: 滑动场景必须计划读取 scrolling_analysis 返回的 batch/root-cause artifact；缺失或无掉帧时执行阶段标记 skipped 并说明
    required_expected_calls:
    - {}
  - id: root_cause_diagnosis
    match_keywords:
    - root
    - cause
    - diagnos
    - 根因
    - 诊断
    - 深入
    - deep
    - jank_frame_detail
    - frame_blocking_calls
    suggestion: 滑动场景建议包含完整卡顿帧根因分析阶段 (jank_frame_detail + frame_blocking_calls + blocking_chain_analysis)
    required_expected_calls:
    - skill_id: jank_frame_detail
    - skill_id: frame_blocking_calls
    - skill_id: blocking_chain_analysis
  - id: architecture_specific_jank
    waivable: false
    trigger_keywords:
    - TextureView
    - SurfaceTexture
    - WebView
    - DrawFunctor
    - React Native
    - RN
    - Fabric
    - JSI
    - GLSurfaceView
    - NativeActivity
    - OpenGL
    - Compose
    - Flutter
    - mixed
    - 混合
    match_keywords:
    - TextureView
    - SurfaceTexture
    - WebView
    - DrawFunctor
    - React Native
    - RN
    - Fabric
    - JSI
    - GLSurfaceView
    - NativeActivity
    - OpenGL
    - Compose
    - Flutter
    - mixed
    - 混合
    - 架构
    suggestion: 非标准/混合渲染架构必须在 plan.expectedCalls 声明对应专属 skill：Flutter 用 flutter_scrolling_analysis，TextureView 用 textureview_producer_frame_timing，其他架构选门禁返回的匹配
      producer/SF skill。执行时拆 HWUI host 链路 + producer 链路 + SF 合成链路，再合并因果，避免只看 FrameTimeline。
    conditional_required_expected_calls:
    - trigger_keywords:
      - Flutter
      - FLUTTER
      required_expected_calls:
      - skill_id: flutter_scrolling_analysis
    - trigger_keywords:
      - TextureView
      - SurfaceTexture
      - TEXTUREVIEW_STANDARD
      required_expected_calls:
      - skill_id: textureview_producer_frame_timing
    - trigger_keywords:
      - WebView
      - DrawFunctor
      required_expected_calls:
      - skill_id: webview_drawfunctor_jank_chain
    - trigger_keywords:
      - RN_OLD_ARCH
      - React Native Bridge
      required_expected_calls:
      - skill_id: rn_bridge_to_frame_jank
    - trigger_keywords:
      - RN_NEW_ARCH
      - Fabric
      - JSI
      required_expected_calls:
      - skill_id: rn_fabric_render_jank
    - trigger_keywords:
      - GLSurfaceView
      - NativeActivity
      - OPENGL
      - GL_STANDALONE
      required_expected_calls:
      - skill_id: gl_standalone_swap_jank
    - trigger_keywords:
      - Compose
      - COMPOSE
      required_expected_calls:
      - skill_id: compose_recomposition_hotspot
    required_expected_call_alternatives:
    - skill_id: flutter_scrolling_analysis
    - skill_id: textureview_producer_frame_timing
    - skill_id: webview_drawfunctor_jank_chain
    - skill_id: rn_bridge_to_frame_jank
    - skill_id: rn_fabric_render_jank
    - skill_id: gl_standalone_swap_jank
    - skill_id: compose_recomposition_hotspot
    - skill_id: surfaceflinger_analysis
```

#### Scrolling Core Strategy

**Route card**: 滑动 / 卡顿 / 掉帧 / jank / scroll / fps / list / fling

**Final report must include**
- 必须显式出现 `### 全帧根因分布`：reason_code/责任方、帧数、占比。
- 必须显式出现 `### 代表帧分析`：耗时、超预算、vsync_missed、四象限/频率、关键 slice/阻塞点、因果链。
- 必须显式出现 `### 峰值/口径指标`：真实掉帧、假阳性、最长帧、最长连续丢帧；缺数据时写缺失来源和降级口径。
- 必须显式分层给出 App/系统建议。

**Detail refs**
- `scrolling:overview_artifacts`: scrolling_analysis、artifact 字段、全局上下文和身份确认。
- `scrolling:architecture_branches`: Flutter/TextureView/WebView/RN/GL/Compose/mixed 分支。
- `scrolling:root_cause_drill`: reason_code 深钻、frame_blocking_calls、blocking_chain_analysis、display pipeline 边界。
- `scrolling:missing_frame_gap`: frame_production_gap 触发和缺帧解释。
- `scrolling:final_report_and_sql_fallback`: 结论结构和 SQL fallback。

#### 滑动/卡顿分析（用户提到 滑动、卡顿、掉帧、jank、scroll、fps）

**⚠️ 核心原则：**
1. **逐帧根因诊断是最重要的**。概览统计（帧率、卡顿率）只是入口，真正有价值的是每一个掉帧帧的根因分析。
2. **掉帧检测以 present_ts 间隔为主**（> 1.5x VSync = 用户可感知卡顿），token_gap 为辅助信号。Buffer Stuffing 帧的 present_type 可以是 Late/Early/On-Time，需用 present_ts 间隔做二次验证。
   - **Per-Layer Buffer 枯竭检测（token-gap 辅助模型）**：当 App Layer 在连续 SF DisplayFrame 中出现 token 跳跃（gap > 1），说明 SF 在中间帧合成时该 Layer 没有新 Buffer = 缓冲区枯竭
   - `token_gap = 1` → 正常（每帧都有新 buffer），`token_gap = N` → 跳过 N-1 个 DisplayFrame
   - 这是 per-layer 检测，不受 SF 全局合成状态影响（SF 可能在消费其他 Layer 的 buffer）
   - **Prediction Error 帧处理**：Prediction Error 帧不应一律忽略。检查 prediction_type = 'Expired Prediction' 的比例：>5% 时标注"FrameTimeline 预测精度不足"。在管线 2-3 帧缓冲下用户可能感知延迟
3. **Guilty Frame 溯源**：
   - BlastBufferQueue 三缓冲下，可见卡顿通常出现在慢帧 2-3 帧之后（管线排空）
   - `guilty_frame_id` 字段指向导致管线枯竭的实际慢帧（向前回溯 ≤5 帧，取最慢的超预算帧）
   - 根因分析（四象限/CPU/Binder）应针对 guilty frame 而非枯竭帧本身
4. **get_app_jank_frames 结果中的 `jank_responsibility` 字段**：
   - `APP`：App 侧原因（App Deadline Missed / Self Jank）
   - `SF`：SurfaceFlinger 侧原因
   - `HIDDEN`：缓冲区枯竭但框架未标记（Perfetto 帧颜色为绿色）
   - `BUFFER_STUFFING`：Buffer Stuffing
5. **Resync 判读边界**：
   - `Choreographer#doFrame - resynced to <vsync> in <x>ms` 是 doFrame 内部 child marker，表示回调已经晚到至少一个 VSync，Choreographer 重新绑定到后续 frame timeline；它不是一帧新的 doFrame，也不是可直接归因给 SF 的合成 slice。
   - `App Resynced Jitter` 属于 App 侧 FrameTimeline jank 类型；报告中应把它作为 App 相位重同步/回调迟到信号，并继续寻找导致迟到的主线程/RT/GPU/BufferQueue 证据。
   - 用户怀疑“resync 后 SF 没合成对应帧、后面帧堆积”时，必须用同 layer token、present_ts 间隔、SF actual/display frame、present_type/dropped frame 或 SF jank_type 证明；不能仅凭 resync marker 下结论。

**Phase 1 — 概览 + 掉帧列表 + 批量根因分类（1 次调用）：**

如果 `process_name` 来自自动焦点检测、或用户/trace 证据提示进程名与包名/线程名/layer 不一致，先执行 **Phase 1.6 进程身份交叉确认**，再调用本阶段的 `scrolling_analysis`。

**Phase 1.3 — 全局上下文检查（基于 `global_context_flags` 结果，scrolling_analysis 自动输出）：**

检查 `global_context` 数据源中的标志。在**结论概述段**（帧率/掉帧率数据紧后）用粗体标注，格式如下：

| 标志 | 条件 | 在结论概述段标注 |
|------|------|----------------|
| `video_during_scroll = 1` | 滑动期间有视频解码活跃 | ⚠️ **视频播放并行**：滑动期间检测到视频解码活跃，workload_heavy 帧的负载归因不能全部归因于滑动渲染 |
| `interpolation_active = 1` | 大量 frame_id=-1 的插帧 | ⚠️ **OEM 插帧模式活跃**：统计指标（帧率/掉帧率）可能受插帧影响失真 |
| `thermal_trending = 1` | trace 尾部频率天花板明显低于峰值 | ⚠️ **温控持续降频**：thermal_throttling 帧的根因是系统级热管理，非 App 问题 |
| `background_cpu_heavy = 1` | 非 App 大核占比 >60% | ⚠️ **后台 CPU 干扰**：{non_app_big_core_pct}% 的大核 CPU 被非前台进程占用。需用 `execute_sql` 查询 top 占用进程 |

⚠️ 全局上下文标志**不改变 reason_code 分类**，仅在结论概述段增加修饰标注。多个标志同时为 1 时全部标注。
<!-- /strategy-detail -->

**混合出图规则：**
1. **先分开看 HWUI host 链路**：始终调用 `scrolling_analysis` 获取宿主 App FrameTimeline、MainThread/RenderThread、SF 责任分布。
2. **再分开看 producer/embedded 链路**：按候选 pipeline 调用对应 skill（Flutter、WebView、TextureView、RN、GL、游戏/媒体）。
3. **最后合并看链路依赖**：判断 producer 是否阻塞/拖慢 host RT、host 是否吞掉 producer 帧、SF 是否在多 layer 中沿用旧 buffer，或两条链路只是并行同屏但无依赖。

**输出必须分三段**：`HWUI host 证据`、`嵌入/独立 producer 证据`、`合并因果判断`。不能只说“这是 Flutter/WebView/RN 架构所以改用某一个 skill”，也不能只说“FrameTimeline 正常所以无卡顿”。

**Phase 1.6 — 进程身份交叉确认（当 process_name 可能不可靠时）：**

处理规则：
- 使用 resolver 第一名候选的 `recommended_process_name_param` 作为后续 `scrolling_analysis` / `jank_frame_detail` / `frame_blocking_calls` 的 `process_name`
- 在结论中把 `canonical_package_name` 当作用户可读的目标应用身份；不要把它和旧 Skill 的 `process_name` 参数混为一谈
- 如果 resolver 只有 `weak_match` 或提示 shared UID，多抓取候选行并说明身份不确定性；必要时先不传 `process_name` 跑全量概览，再按 `upid`/线程/layer 过滤
<!-- /strategy-detail -->

<!-- strategy-detail id="root_cause_drill" title="滑动根因分支深钻和 display pipeline 边界" keywords="root cause,reason_code,jank_frame_detail,frame_blocking_calls,blocking_chain_analysis,SurfaceFlinger,Fence,BufferQueue" -->
**Phase 1.7 — 根因分支深钻（基于 batch_frame_root_cause 的 reason_code 和 jank_responsibility）：**

**Display pipeline 边界（当证据命中 SF/BufferQueue/Fence/刷新率时必须写清）：**
- `queueBuffer()` 只证明 producer 已提交 buffer；它不证明 SurfaceFlinger 已 acquire/latch，也不证明 HWC/panel 已 present。
- `dequeueBuffer` 长等通常更接近 release fence / BufferQueue backpressure / triple-buffer 槽位复用问题；不要把它直接写成 App 主线程代码慢。
- Fence 要拆成 acquire / present / release：acquire 影响 SF latch，present 影响用户可见上屏，release 影响 producer 复用上一帧 buffer。
- HWC 不是 BufferQueue consumer；SurfaceFlinger 消费 buffer 后，再通过 HWC validate/accept/present 或 RenderEngine 合成。
- 刷新率/ARR/VRR 会改变帧预算。报告必须基于 `vsync_config`、VSYNC-sf、FrameTimeline 或等价证据，不默认 16.6ms。
- GraphicBuffer/dma-buf 是图形物理内存证据面；BufferQueue/Fence slice 只能证明队列、同步和背压候选，不能单独证明图形内存泄漏或占用峰值。

**Phase 1.8 — 帧内指标 / GPU / CPU 利用率补充（按需执行）：**

当用户追问"每帧 CPU/UI 时间"、"GPU work period"、"Mali power state"、"是 CPU 还是 GPU 限制"时，优先调用已落地的 B-tier atomic skill：

这些是补充证据，不替代 Phase 1.9 的根因深钻。若 Trace 数据完整度提示 `gpu_work_period` / `cpu_freq_idle` 缺失，结论中必须说明 GPU/CPU 供应侧判断的可信度下降。

**Phase 1.9 — 根因深钻（🔴 强制执行，不可跳过）：**

**常见错误：** 看到 reason_code=workload_heavy 就结论"工作负载过重"，但没有回答：具体是哪段代码？为什么在这个时机执行？是否可异步/分帧？这不是根因分析，这只是分类。

**workload_heavy 子分类指导：** 当 reason_code = `workload_heavy` 时，检查 `top_slice_name` 字段是否**包含**以下关键字，进一步归类（这是字符串包含匹配，不是 SQL 查询）：

| top_slice_name 包含 | 子分类 | 优化方向 |
|--------------------|--------|---------|
| `Choreographer` / `doFrame` / `doCallbacks` | doFrame 回调总时间过长 | [App层] 检查 measure/layout/draw 各阶段，减少过度绘制 |
| `layout` / `measure` / `onLayout` / `onMeasure` | 布局计算密集 | [App层] 减少嵌套层级，使用 ConstraintLayout，避免 requestLayout 连锁 |
| `obtainView` / `inflate` / `createViewFromTag` / `RecyclerView` / `prefetch` | View 创建/Inflate/预取过长 | [App层] 启用 RecyclerView 预创建、异步 inflate、ViewStub 延迟加载 |
| `animation` / `Animator` / `ValueAnimator` | 动画回调过长 | [App层] 检查是否有多个动画叠加，或动画回调中执行了耗时操作 |
| `input` / `dispatchTouchEvent` / `onTouch` / `onScrollChanged` | 输入处理阻塞 | [App层] 优先查看 `input_stage`、`input_slice_ms`、`input_events_json`，避免在 onTouchEvent/onScrollChanged 中执行耗时同步逻辑 |
| `decodeBitmap` / `BitmapFactory` / `decodeResource` / `decode` | 主线程图片解码 | [App层] 使用 Glide/Coil 异步加载，避免主线程 decode |
| `SharedPreferences` / `sqlite` / `QueuedWork` / `waitToFinish` | 主线程 IO | [App层] 迁移到 DataStore/Room 异步 API，避免 apply() 后 waitToFinish |
| `traversal` / `performTraversal` / `relayoutWindow` | ViewRootImpl traversal 过长 | [App层] 减少 View 树深度，检查是否有不必要的 invalidate |
| `Recomposition` / `compose:` | Compose 重组过长 | [App层] 使用 derivedStateOf/remember 减少不必要的重组 |
| 其他 / 无法匹配 | 通用负载过重 | 需要 jank_frame_detail 查看 main_slices_json 获取更多上下文 |

**WHY 链深度要求：** 每个 [CRITICAL]/[HIGH] 发现的根因推理链必须至少 2 级：
- ✅ Level 1: "帧超时" → Level 2: "Binder 阻塞" → Level 3: "服务端 system_server monitor_contention"
- ❌ 仅 Level 1: "帧超时 45ms，workload_heavy"（缺少机制解释）
<!-- /strategy-detail -->

<!-- strategy-detail id="missing_frame_gap" title="缺帧检测和 production gap" keywords="frame_production_gap,missing frame,缺帧,production gap,Buffer Stuffing" -->
**Phase 1.95 — 缺帧检测（满足以下任一条件时执行）：**

| 触发条件 | 说明 |
|----------|------|
| `real_jank_count < 5` 但 `scroll_sessions` 存在 ≥2 个滑动区间 | 滑动区间存在但几乎无肥帧 → 可能是缺帧导致的感知卡顿 |
| `jank_type_stats` 中 `false_positive` 占比 > 50% | 大量 Buffer Stuffing 假阳性 → 管线问题可能伴随缺帧 |
| 检测到 WebView / SurfaceTexture 架构（Phase 1.5） | 单 buffer 模式天然容易产生缺帧 |

缺帧在 Perfetto 时间线上表现为帧间 gap 而非红/黄帧，`batch_frame_root_cause` 无法检出。


返回结果包含：
- `gap_overview`：Gap 总数、分类统计（ui_no_frame / rt_no_drawframe / sf_backpressure）、最长 Gap
- `gap_list`：每个 Gap 的详细信息（时间、VSync 数、类型、doFrame/DrawFrame 计数）

**缺帧类型解读：**

| Gap 类型 | 含义 | 常见原因 | 优化方向 |
|----------|------|---------|---------|
| `ui_no_frame` | UI Thread 未触发 doFrame | 按压/松手时无触摸事件驱动、滑动到顶/底部内容已耗尽、App 主动调用 `setFrameRate()` 限帧 | [App层] 检查 Input 事件流、滑动边界处理 |
| `rt_no_drawframe` | 有 doFrame 但 RenderThread 未执行 DrawFrame | doFrame 中 measure/layout 判定无 dirty 区域（View 未 invalidate）、syncFrameState 超时被跳过 | [App层] 检查是否有冗余 requestLayout 但无实际绘制 |
| `sf_backpressure` | 有 DrawFrame 但帧未被 SF 消费 | SurfaceTexture 单 buffer 覆盖（WebView/Camera）、BlastBufferQueue 背压、SF 端 dequeue 延迟 | [系统层] 检查 BufferQueue 状态、SF 合成延迟 |
| `production_gap` | 其他原因的帧中断 | 进程被冻结（后台化）、ANR 状态、系统低内存 killing | 检查进程状态和系统级事件 |

⚠️ 缺帧和肥帧可以同时存在。**先分析 batch_frame_root_cause（肥帧），再用 frame_production_gap（缺帧）补充**。
<!-- /strategy-detail -->

<!-- strategy-detail id="final_report_and_sql_fallback" title="滑动最终报告结构和 SQL 回退方案" keywords="conclusion,final report,SQL,fallback,全帧根因分布,代表帧" -->
**Phase 2 — 补充深钻（可选，仅在 Phase 1.9 深钻后仍需更多细节时执行）：**
Phase 1 的 `batch_frame_root_cause` 已包含每帧的**完整统计数据**（但统计数据 ≠ 根因，Phase 1.9 的工具调用深钻不可省略）：
- MainThread 四象限（Q1 大核运行 / Q2 小核运行 / Q3 调度等待 / Q4 休眠）
- RenderThread 四象限（render_q1 大核 / render_q3 调度 / render_q4 休眠）
- CPU 大核频率（big_avg_freq_mhz / big_max_freq_mhz）+ 升频延迟（ramp_ms）
- Binder 同步重叠（binder_overlap_ms）+ GC 重叠（gc_overlap_ms）
- Input 管线证据（input_stage / input_slice_ms / input_handling_ms / input_event_count / input_events_json）
- 根因分类（reason_code）+ 关键操作（top_slice_name / top_slice_ms）

此外，每个滑动区间的**整体运行特征**（四象限分布、CPU 频率、关键线程大小核分布）已内嵌在 `scroll_sessions` 的展开行中（由 `session_stats_batch` 提供），无需调用 jank_frame_detail 或 blocking_chain_analysis 来获取全局指标。兼容数据源 `session_quadrant_summary`、`session_cpu_freq`、`session_thread_core_affinity` 仍可通过 save_as 引用。

**batch_frame_root_cause 的统计数据可用于分类和概览，但 Phase 1.9 的深钻工具调用不可省略**。jank_frame_detail 仅在以下特殊情况需要调用：
仅在以下情况才调用 jank_frame_detail（**最多 2 帧**）：
- 需要查看 CPU 频率**时间线**（帧内频率变化过程）
- 需要查看 RenderThread 或主线程的 top N slices 详情
- **reason_code 为 unknown 且帧数 >5%**：必须对至少 1 帧调用 jank_frame_detail 获取更多线索，不能在分布表中仅标记"未分类"就跳过
- reason_code 与实际数据矛盾时（如 `lock_binder_wait` 但 Binder 耗时 0ms）：应在结论中标注可能的误分类原因

如果深钻结果已给出更具体的根因，不要在最终报告继续把原始 `reason_code` 当作根因名称。典型例子：
- `lock_binder_wait` 但 `binder_overlap_ms=0`，且 `render_slices_json` 出现 `cache_miss: makePipeline` / shader 编译 / Vulkan finish frame / `postAndWait`，最终根因应写成 **shader_compile + sync_wait** 或等价机制，并说明 `lock_binder_wait` 是批量分类误判。
- `workload_heavy` 但 `main_slices_json` 明确指向应用自定义方法，最终根因应写具体方法名和所处阶段，例如 `CustomScroll_longFrameLoad` 在 ANIMATION 回调同步执行，而不是只写 "workload_heavy"。

`frame_blocking_calls` 是 Phase 1.9 的帧内阻塞证据补充，不占 `jank_frame_detail` 的 2 帧上限。遇到 Binder/IO/futex/锁相关根因时，优先用它确认阻塞调用是否真的与掉帧帧重叠。


**Phase 3 — 综合结论（基于全量帧数据）：**

**输出结构必须遵循。以下三个小节标题必须显式出现在最终报告中：`### 全帧根因分布`、`### 代表帧分析`、`### 峰值/口径指标`。**

1. **概览**（必须包含以下数据）：
   - 总帧数、**总真实掉帧数 = SUM(所有 jank_type 行的 real_jank_count)**
   - 分类明细：App 侧掉帧 N 帧 + 隐形掉帧 N 帧 + 假阳性 N 帧
   - **峰值体验指标**（仅看掉帧率会掩盖极端长帧对用户感知的影响）：
     - 最长帧耗时：XXms（超预算 N 倍）
     - 最长连续丢帧 VSync 数：N 个 VSync（= XXms 无响应）
     - 如有 >3 帧超过 3× VSync 预算，标注"存在用户强感知卡顿峰值"
   - **综合评级标准**（不能只看掉帧率，必须同时考虑峰值）：
     - 优秀：掉帧率 <1% 且最长帧 <2× VSync
     - 良好：掉帧率 <3% 且最长帧 <4× VSync
     - 一般：掉帧率 <5% 或最长帧 <8× VSync
     - 差：掉帧率 ≥5% 或最长帧 ≥8× VSync
     - 例：掉帧率 2% 但最长帧 62ms（7.5× VSync）→ 评级应为"一般"而非"良好"
   - **指标口径说明**：FPS 基于滑动时间窗口（非分析耗时），时间范围需标注来源
   - 如果存在隐形掉帧（`jank_type=None` 但 `real_jank_count > 0`），**必须在概览中明确标注**：
     "其中 N 帧为隐形掉帧（框架未标记但消费端检测到真实掉帧），可能与 SurfaceFlinger 合成延迟、管线积压或跨进程 Binder 阻塞有关"
   - ⚠️ **`App Deadline Missed` 不等于全部真实掉帧**。例如 135 帧 App Deadline Missed + 165 帧隐形掉帧 = 300 总真实掉帧

   最终报告中必须把上述峰值体验和指标口径整理到 `### 峰值/口径指标` 小节，不能只散落在概览或建议里。

2. **各滑动区间运行特征**（from scroll_sessions 展开行，或兼容数据源 session_quadrant_summary / session_cpu_freq / session_thread_core_affinity）：
   - 对每个滑动区间分别报告（如有多个区间，逐区间列出）：
   - 主线程四象限：Q1=XX% Q2=XX% Q3=XX% Q4a=XX% Q4b=XX%
   - RenderThread 四象限：Q1=XX% Q3=XX% Q4a=XX% Q4b=XX%
   - CPU 频率：prime 均频 XXMHz / big 均频 XXMHz / little 均频 XXMHz
   - 关键线程大小核分布：MainThread prime XX%+big XX% / RenderThread prime XX%+big XX%

3. **全帧根因分布**（基于 batch_frame_root_cause，覆盖所有掉帧帧）：
   按 reason_code 聚合，附带四象限分布和频率特征：
   ```
   | 根因类型 | 帧数 | 占比 | 四象限特征 | 频率特征 |
   |---------|------|------|-----------|---------|
   | workload_heavy | 80 | 59% | Q1=45% Q3=8% | 大核均频 2200MHz |
   | freq_ramp_slow | 30 | 22% | Q1=30% Q3=12% | 大核均频 1100MHz, ramp>10ms |
   | small_core_placement | 15 | 11% | Q2=55% | 大核均频 900MHz |
   | ... | ... | ... | ... | ... |
   ```

4. **代表帧分析**（每个根因类别选最严重的 1 帧，从 batch 数据中直接引用）：
   ```
   ### [reason_code] 代表帧: [start_ts] — [jank_responsibility]
   - 帧耗时：XXms（帧预算 XXms）
   - 主线程：Q1=XX% Q2=XX% Q3=XX% Q4=XX%
   - RenderThread：Q1=XX% Q3=XX% Q4=XX%
   - 关键操作：[top_slice_name] 耗时 XXms
   - CPU 频率：均频 XXMHz / 峰频 XXMHz，升频延迟 XXms
   - Binder: XXms / GC: XXms
   - Input: 阶段 [input_stage] / 重叠 XXms / 最慢处理 XXms（如有 input 证据）
   ```
   如有额外深钻帧（来自 jank_frame_detail），标注其 CPU freq timeline 和 slices 详情。

   如果代表帧涉及 SF/BufferQueue/Fence/刷新率，必须追加一行 display pipeline 拆分：
   `App/RT -> BufferQueue -> SF commit/composite -> HWC/display -> fence`，并说明缺的是
   acquire、present 还是 release fence 证据。不要把 `queueBuffer` 快写成“已上屏”，也不要把
   GraphicBuffer/dma-buf 内存证据写成 BufferQueue 槽位证据。

5. **优化建议**：按根因类别给出可操作建议，优先级按帧数占比排序。**必须分层标注**：
   - **[App 层]**：App 开发者可直接实施的优化（异步化、分帧、预加载、减少主线程阻塞等）— 建议要具体到代码模式
   - **[系统/ROM 层]**：需要厂商协同或系统级权限的优化（governor 调优、thermal 策略、SCHED_UTIL_CLAMP 等）— 标注"需系统级能力"
   - 优先给出 App 层建议；系统层建议仅作为补充参考

**当报告隐形掉帧时，必须提醒用户：**
- 隐形掉帧在 Perfetto 时间线上帧颜色为**绿色**（框架标记 jank_type=None）
- 真实卡顿证据是 **VSYNC-sf 计数器轨道**上的呈现间隔异常（> 1.5x VSync 周期）
- 可参考帧列表中的"呈现间隔"列确认

⚠️ **结论必须覆盖所有掉帧帧的根因分布**，不能只报告少数几帧。
   batch_frame_root_cause 提供了全量分类和详细指标，结论中的"全帧根因分布"和"代表帧分析"都应基于它。

---

#### 滑动场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_frame_stats`、`android_frames_overrun`、`android_surfaceflinger_workloads`、`android_gpu_frequency`、`cpu_thread_utilization_in_interval(ts, dur)`、`cpu_frequency_counters`、`slice_self_dur`、`android_screen_state`

---

#### 滑动分析的 SQL 回退方案

**当 scrolling_analysis Skill 返回 success=false 或 get_app_jank_frames 为空时**，按以下步骤走：

**回退 Step 1 — 消费端真实掉帧检测（含隐形掉帧）：**

```sql
WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
),
vsync_cfg AS (
  SELECT COALESCE(
    (SELECT CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER)
     FROM vsync_intervals
     WHERE interval_ns BETWEEN 4000000 AND 50000000),
    16666667
  ) as period_ns
),
frames AS (
  SELECT a.ts, a.dur, a.jank_type,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '{process_name}*' OR '{process_name}' = '')
    AND p.name NOT LIKE '/system/%'
)
SELECT printf('%d', ts) AS start_ts, printf('%d', ts + dur) AS end_ts,
  ROUND(dur/1e6, 2) AS dur_ms, jank_type,
  CASE WHEN jank_type = 'None' OR jank_type IS NULL THEN '隐形掉帧' ELSE jank_type END as display_type,
  CASE
    WHEN jank_type = 'None' OR jank_type IS NULL THEN 'HIDDEN'
    WHEN jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
    ELSE 'APP'
  END as responsibility,
  MAX(CAST(ROUND((present_ts - prev_present_ts) * 1.0 / (SELECT period_ns FROM vsync_cfg) - 1, 0) AS INTEGER), 0) as vsync_missed
FROM frames
WHERE prev_present_ts IS NOT NULL
  AND (present_ts - prev_present_ts) <= (SELECT period_ns FROM vsync_cfg) * 6
  AND (present_ts - prev_present_ts) > (SELECT period_ns FROM vsync_cfg) * 1.5
ORDER BY vsync_missed DESC, dur DESC
LIMIT 20
```

⚠️ 注意：此 SQL 同时返回框架标记的掉帧和隐形掉帧。`display_type='隐形掉帧'` 的帧是框架未标记但消费端检测到的真实掉帧。

**回退 Step 2 — 对 top 5 卡顿帧调用 jank_frame_detail（必须执行）：**
- 混合选取 APP 和 HIDDEN 帧

**不执行逐帧分析就直接出结论是不允许的。**
<!-- /strategy-detail -->
