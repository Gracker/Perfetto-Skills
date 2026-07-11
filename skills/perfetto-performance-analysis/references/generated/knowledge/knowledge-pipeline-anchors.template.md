GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/knowledge-pipeline-anchors.template.md
Source SHA-256: 6872ffa1c53bf15aa1766d57bc1322c7a44c3e8ccdb75af64fe730e3c57866c0
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Knowledge Pipeline Anchors Template

Portable methodology extracted from the SmartPerfetto strategy library.

# 12 锚点详解（Article-Grounded）

本模板是 S01 §12 个锚点的完整详解。Agent 在 jank 归因时应明确把症状定位到具体锚点。

## 生产阶段（App 这一半）

### ① vsync-app

- **触发**：Display 给出下一次刷新节奏 → SF Scheduler 按 app workDuration 通过 EventThread 回调给订阅者（DisplayEventReceiver）
- **现代实现**（Android 10+）：`VSyncTracker` / `VSyncDispatch` / `VSyncReactor`，基于预测 present time 反推应用工作起点（旧称 `app offset`，已是过时口径）
- **观察点**：SF 进程的 `vsync-app` counter（注意：不代表你的 App 一定开始跑这一帧）；更可靠是 App 进程的 `Choreographer#doFrame` slice
- **常见问题**：App 没注册 vsync（看不到 `Choreographer#doFrame`）、节奏不稳（counter 间隔抖动）

### ② Choreographer.doFrame（5 callbacks）

- **顺序**：`CALLBACK_INPUT → CALLBACK_ANIMATION → CALLBACK_INSETS_ANIMATION（Android 11+） → CALLBACK_TRAVERSAL → CALLBACK_COMMIT`
- **CALLBACK_INPUT**：batched motion events 的帧同步重采样（不是普通输入排队）
- **CALLBACK_ANIMATION**：属性动画、`OverScroller` 物理推进、插值器；fling 时这里推位移而非 Input
- **CALLBACK_INSETS_ANIMATION**：系统栏 / 键盘动画引发的 insets 变化合并
- **CALLBACK_TRAVERSAL**：`measure → layout → draw`（HWUI 路径）；末尾通过 `syncAndDrawFrame()` 交接 RenderThread
- **CALLBACK_COMMIT**：本帧收尾，可用于厂商 pre-animation 提前计算下一帧
- **常见问题**：某段独占预算（典型 TRAVERSAL 因深嵌套 ViewGroup measure 反复触发）

### ③ syncAndDrawFrame

- **位置**：`CALLBACK_TRAVERSAL` 执行栈末尾（不是独立 callback 类型）
- **机制**：UI Thread 调用 `syncAndDrawFrame()` → native 经 `RenderProxy` 投递 `DrawFrameTask` 到 RenderThread
- **同步边界**：UI Thread 可以 block 在 RenderThread 上，RenderThread 不能反过来 block UI Thread
- **常见问题**：UI Thread 等 RenderThread 时间过长（DrawFrameTask 起跑晚 + sync 边界等不到放行）

### ④ dequeueBuffer

- **位置**：RenderThread `CanvasContext::draw()` 内部
- **机制**：RT 从 BBQ 取一个可写 buffer slot，可能等 release fence signal
- **BufferSlot 4 状态**：FREE → DEQUEUED → QUEUED → ACQUIRED（再回到 FREE）
- **常见问题**：dequeueBuffer 长等通常不是 GPU 慢——是上一帧 slot 卡 ACQUIRED 状态（HWC 还在显示 / SF 没采纳 / 可用 slot 数不够深）

### ⑤ Skia/GPU

- **位置**：RenderThread `CanvasContext::draw()` 内部
- **机制**：dirty 区域计算 → 准备 frame/surface → render pipeline `draw(...)` → GPU 命令下发 → `swapBuffers(...)`
- **关键：CPU 侧 `queueBuffer` 返回 ≠ GPU 已写完**，由 acquire fence 异步保护
- **常见问题**：GPU 慢（shader 复杂、overdraw、texture 重）、driver 反压（GPU stall）、swap 等待 vsync

### ⑥ queueBuffer → Transaction

- **关键事实**：`queueBuffer` 是 Producer 侧结束信号，**buffer 进入 BBQ**；不是直接到 SF
- **BLAST 路径**：BBQ 把 buffer + 窗口状态打包成 Transaction → SF
- **Legacy 路径**（Android 12 之前）：跨进程独立 BufferQueue 直接送 SF
- **⚠️ BufferTx counter +1 时机**：在 SF 进程 Transaction 到达时，**不是** queueBuffer 返回时
- **常见问题**：几何变化与 buffer 提交不同帧（Legacy 易撕裂；BLAST 用 sync transaction 解决）

## 系统这一半

### ⑦ vsync-sf

- **触发**：SF Scheduler 按 sf workDuration 起跑（与 vsync-app 错开 phase）
- **现代实现**：同 vsync-app，由 `VSyncTracker`/`VSyncDispatch` 基于预测 present time 反推
- **观察点**：SF 进程的 `vsync-sf` counter
- **常见问题**：SF Duration 抬升导致 sf phase 不够（多 layer 场景 / HWC 决策成本高）

### ⑧ latch

- **机制**：SF 进入本轮合成，对每个 target layer 等 acquire fence signal 后 `acquireBuffer`
- **latch unsignaled buffer 优化**（AutoSingleLayer 模式）：单 layer 单 pending buffer + 无 sync transaction 时可先 latch 推进流程，到读取 buffer 内容更后面阶段再等 fence
- **常见问题**：
  - 没 latch 成功 → 沿用旧 buffer（多帧没采纳 = 用户看到旧画面，可能是 acquire fence 安全边界）
  - 多 layer 场景：本轮 SF 只采纳部分 layer 新内容 → 用户看到"新旧混合"

### ⑨ HWC validate / acceptChanges

- **5 步谈判**：
  1. SF 为每个 layer 声明期望 composition type（DEVICE/CLIENT/SOLID_COLOR/CURSOR/SIDEBAND）
  2. SF 调 `validateDisplay()`，HWC 评估硬件能力
  3. SF 调 `getChangedCompositionTypes()` 查 HWC 把哪些 layer 从 DEVICE 降级为 CLIENT
  4. SF 对降级 layer 补做 client composition（⑩）
  5. SF 调 `acceptDisplayChanges()` + `presentDisplay()` 送显
- **HWC2 优化**：`skipValidate` 满足条件可跳过 validate 直接 present
- **HWC 决策因素**：透明混合 / 旋转/缩放 / 受保护内容 / 视频字幕叠加 / 硬件 plane 数量上限 / 色彩空间 HDR
- **常见问题**：layer 数量过多 / 包含 alpha / 旋转 → 触发 client composition 降级

### ⑩ client composition（按需）

- **触发**：HWC 把不能 device composition 的 layer 打回 SF
- **机制**：SF 用 GPU 把这些 layer 合到 client target buffer，再交回 HWC 走 device composition
- **代价**：GPU 工作压在 SF 进程，挤占应用自己的 GPU 预算 + 带宽
- **常见问题**：相邻几帧 device ↔ client 反复抖动（HWC 决策不稳）→ 功耗周期性抬升

### ⑪ presentDisplay

- **HWC 调用**：实际把帧交给 display controller
- **per-display per-frame**：每个 display 一份
- **产出**：present fence（每次 present 一份）+ release fences（每个 layer 一份）

### ⑫ scan-out + present fence

- **scan-out**：display controller 把帧扫到 panel 像素
- **present fence signal**：表示扫描输出真正完成
- **关键**：用户什么时候看到 = present fence signal 时刻
- **panel 因素**：刷新率切换、Panel 模式切换、扫描输出本身延迟（DSI / DP）
- **常见问题**：present fence 持续偏晚但 latch 不晚 → 系统收尾段问题（panel/DVFS/扫描输出）

## 锚点偏离表（17+ 类型）

每个 pipeline yaml 的 `meta.deviation_anchors` 字段标注了相对 12 锚点的偏离描述。常见模式：

| 偏离描述 | 类型 | 说明 |
|---------|------|------|
| `baseline_complete_1_to_12` | ANDROID_VIEW_STANDARD_BLAST | 完整覆盖 12 锚点 |
| `baseline_legacy_no_blast_anchor_6` | ANDROID_VIEW_STANDARD_LEGACY | ⑥ 用 Binder BufferQueue，无 Transaction 原子性 |
| `skips_renderthread_anchor_5` | ANDROID_VIEW_SOFTWARE | ⑤ 在 main thread 做 CPU 栅格化 |
| `multi_path_anchor_4_5_6` | ANDROID_VIEW_MIXED | 多条 ④⑤⑥ 并行；⑧ 多 layer latch |
| `serialized_multi_viewroot_anchor_2_3_4_5` | ANDROID_VIEW_MULTI_WINDOW | 同进程多窗口 ②③④⑤ 串行 |
| `independent_anchor_4_5_6_join_at_8` | SURFACEVIEW_BLAST | 独立 ④⑤⑥；⑧ 多 layer latch |
| `host_resample_anchor_4_5_anchor_5_anchor_6` | TEXTUREVIEW_STANDARD | 双次 ⑤（外部 GPU + 宿主 RT 重采样） |
| `engine_anchor_2_3_4_5_6_at_engine_threads` | FLUTTER_SURFACEVIEW_* | Engine 接管 ②③④⑤⑥ |
| `engine_to_host_resample_*` | FLUTTER_TEXTUREVIEW | Engine + 宿主 RT 双层处理 |
| `host_rt_replay_anchor_5_at_host_rt` | WEBVIEW_GL_FUNCTOR | Chromium DDL 在宿主 RT replay |
| `multiprocess_chromium_arch_*` | CHROME_BROWSER_VIZ | 多进程 Chromium 链路 |
| `engine_main_loop_anchor_2_3_4_5_6` | GAME_ENGINE | 引擎主循环代替 Choreographer |
| `no_vsync_app_hardware_sensor_trigger` | CAMERA_PIPELINE | sensor 节奏，不等 vsync-app |
| `tunneled_skips_anchor_10_or_overlay_*` | VIDEO_OVERLAY_HWC | Tunneled 跳过 ⑩ client composition |
| `ndk_direct_anchor_4_5_6_no_view_root` | SURFACE_CONTROL_API | NDK 绕过 ViewRootImpl |
| `cross_cutting_feature_at_anchor_7_to_12` | VARIABLE_REFRESH_RATE | 显示策略改进，不是独立 pipeline |
| `anchor_10_client_composition_when_hwc_rejects` | SOFTWARE_COMPOSITING | SF 侧 client composition 路径 |

## 用法

Agent 在归因时应：
1. 先用 `pipeline_result` 选定 primary pipeline
2. 查该 pipeline yaml 的 `meta.deviation_anchors` 知道正常情况下哪些锚点是基线、哪些已偏离
3. 把症状定位到具体锚点（① doFrame 起晚？④ dequeue 卡？⑧ latch 失败？⑫ present 偏晚？）
4. 再追该锚点的常见根因
