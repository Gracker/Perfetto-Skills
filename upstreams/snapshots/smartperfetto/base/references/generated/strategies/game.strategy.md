GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/game.strategy.md
Source SHA-256: 565700969ffb3250d91821b346d89a012a8b10edd90f5759d27a6fa573ae38b8
Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

# Game Strategy

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
scene: game
priority: 4
effort: medium
required_capabilities:
- cpu_scheduling
optional_capabilities:
- gpu
- thermal_throttling
- surfaceflinger
- gpu_work_period
- power_rails
- cpu_freq_idle
keywords:
- 游戏
- game
- 帧率
- 游戏卡顿
- 游戏掉帧
- unity
- unreal
- 游戏性能
- game fps
- game performance
- godot
- cocos
compound_patterns:
- 游戏.*卡
- 游戏.*帧
- game.*jank
- game.*fps
phase_hints:
- id: game_loop_jank
  keywords:
  - game
  - Unity
  - Unreal
  - Cocos
  - Godot
  - 主循环
  - Tick
  - PlayerLoop
  - GameThread
  - 帧率
  - 卡顿
  constraints: 游戏/引擎场景必须先用 game_fps_analysis 看整体帧率，再用 game_main_loop_jank 检查引擎主循环/Tick 超预算切片。不要把缺 FrameTimeline 误判成没有掉帧。
  critical_tools:
  - game_fps_analysis
  - game_main_loop_jank
  critical: true
- id: game_gpu_power
  keywords:
  - gpu
  - work period
  - mali
  - thermal
  - 功耗
  - 发热
  - 降频
  constraints: GPU/功耗/发热问题按数据完整度补充 android_gpu_work_period_track、mali_gpu_power_state、thermal_throttling、wattson_thread_power_attribution；缺
    capability 时标注证据等级。
  critical_tools:
  - android_gpu_work_period_track
  - mali_gpu_power_state
  - thermal_throttling
  - wattson_thread_power_attribution
  critical: false
plan_template:
  mandatory_aspects:
  - id: fps_and_gpu
    match_keywords:
    - game
    - fps
    - 游戏
    - gpu
    - frame
    - 帧率
    suggestion: 游戏场景建议包含帧率分析和 GPU 状态检查阶段
    required_expected_calls:
    - skill_id: game_fps_analysis
  - id: engine_loop_jank
    match_keywords:
    - Unity
    - Unreal
    - Cocos
    - Godot
    - GameThread
    - PlayerLoop
    - Tick
    - 主循环
    suggestion: 游戏引擎场景建议包含 game_main_loop_jank 阶段，检查引擎自管帧循环
    required_expected_calls:
    - skill_id: game_main_loop_jank
```

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

**Phase 1 — 游戏帧率分析（1 次调用）：**
返回：帧率统计、帧间隔分布、卡顿帧列表。

**Phase 1.5 — 引擎主循环 / Tick 深钻：**


检查 Unity `PlayerLoop` / `Camera.Render` / `Gfx.WaitForPresent`、Unreal `FrameGameThread` / `GameThread` / `RHIThread`、Cocos `Director::mainLoop`、Godot `Main::iteration` 等切片是否超过目标帧预算。该阶段补的是应用生产端节奏，不能用 FrameTimeline 缺失来证明游戏无卡顿。

**Phase 2 — GPU 深度分析（推荐）：**

游戏通常是 GPU-bound。调用 GPU 相关分析：
检查 GPU 频率/利用率、Fence 等待时间。

如果 Trace 数据完整度显示 `gpu_work_period` 可用，再补充：
用于判断 GPU active region 是否连续、Mali power state 是否异常。无 `gpu_work_period` 时只能做 GPU 频率/帧间隔定性分析。

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
