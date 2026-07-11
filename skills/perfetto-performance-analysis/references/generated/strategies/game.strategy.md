GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/game.strategy.md
Source SHA-256: 565700969ffb3250d91821b346d89a012a8b10edd90f5759d27a6fa573ae38b8
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Game Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

`execute_sql(...)` examples mean to run the contained SQL through `perfetto_query.py`; they do not require a product tool.

#### game Core Strategy

**Route card**: 游戏 / game / 帧率 / 游戏卡顿 / 游戏掉帧 / unity / unreal / 游戏性能 / game fps / game performance

**Capabilities**: required=[cpu_scheduling], optional=[gpu, thermal_throttling, surfaceflinger, gpu_work_period, power_rails, cpu_freq_idle]





**Phase reminders**
- game_loop_jank: 游戏/引擎场景必须先用 game_fps_analysis 看整体帧率，再用 game_main_loop_jank 检查引擎主循环/Tick 超预算切片。不要把缺 FrameTimeline 误判成没有掉帧。 工具: game_fps_analysis, game_main_loop_jank
- game_gpu_power: GPU/功耗/发热问题按数据完整度补充 android_gpu_work_period_track、mali_gpu_power_state、thermal_throttling、wattson_thread_power_attribution；缺 capability 时标注证据等级。 工具: android_gpu_work_period_track, mali_gpu_power_state, thermal_throttling, wattson_thread_power_attribution

**Final report contract summary**
- 遵循通用输出契约。





<!-- strategy-detail id="full" title="game full strategy detail" keywords="game,游戏,game,帧率,游戏卡顿,游戏掉帧,unity,unreal,游戏性能,game fps,game performance,godot,cocos,游戏性能分析（用户提到 游戏、game、帧率、游戏卡顿）,detail,full" default="true" -->
#### 游戏性能分析（用户提到 游戏、game、帧率、游戏卡顿）

游戏渲染管线与标准 Android View 不同：没有 FrameTimeline，不使用 Choreographer/RenderThread 流程。
需要使用 `game_fps_analysis`（非 `scrolling_analysis`）作为入口。

#### 游戏场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_gpu_frequency`、`cpu_utilization_per_second`、`cpu_frequency_counters`、`android_dvfs_counters`、`android_screen_state`



**Phase 1.5 — 引擎主循环 / Tick 深钻：**



检查 Unity `PlayerLoop` / `Camera.Render` / `Gfx.WaitForPresent`、Unreal `FrameGameThread` / `GameThread` / `RHIThread`、Cocos `Director::mainLoop`、Godot `Main::iteration` 等切片是否超过目标帧预算。该阶段补的是应用生产端节奏，不能用 FrameTimeline 缺失来证明游戏无卡顿。

**Phase 2 — GPU 深度分析（推荐）：**





**Phase 3 — 系统级交叉分析：**



**Phase 4 — 引擎特定分析：**

| 引擎 | 关键线程 | 关键 Slice |
|------|---------|-----------|
| Unity | UnityMain, UnityGfx | `PlayerLoop`, `Gfx.WaitForPresent`, `Camera.Render` |
| Unreal | GameThread, RHIThread, RenderThread | `FrameGameThread`, `RHIThread`, `RenderingThread` |
| Godot | GodotMain | `Main::iteration`, `physics_process` |

**输出结构：**

1. **帧率概览**：平均/P50/P90/P99 帧间隔、稳定性评级
2. **卡顿帧分析**：卡顿帧时间分布、帧间隔直方图
3. **GPU 状态**：频率、利用率、Fence 等待
4. **热节流影响**：CPU/GPU 频率是否被限制
5. **优化建议**：按 GPU-bound / CPU-bound / Thermal 分类
<!-- /strategy-detail -->
