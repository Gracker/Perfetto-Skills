GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/general.strategy.md
Source SHA-256: ee8e41f175846136b1af81f0467bb8ebdada0a34a5941b3df53293ea8730ba03
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# General Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### general Core Strategy

**Route card**: general

**Capabilities**: required=[cpu_scheduling], optional=[none]





**Phase reminders**
- 无额外 phase hint。

**Final report contract summary**
- 遵循通用输出契约。


**Detail ref**
- `general:full`: 通用分析 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="general full strategy detail" keywords="general,通用分析,detail,full" default="true" -->
#### 通用分析

当前查询未匹配到特定场景策略。请根据用户关注的方向，使用以下决策树选择合适的分析路径。

**决策树 — 按用户关注方向路由：**



**场景专用快速路由**（如果用户的问题明确匹配以下场景，直接使用对应策略）：
- **滑动/卡顿**: scrolling_analysis → jank_frame_detail (逐帧深钻)
- **启动**: startup_analysis → startup_detail
- **ANR**: anr_analysis → anr_detail
- **点击/触摸**: click_response_analysis → click_response_detail (逐事件深钻)
- **TextureView/WebView/Flutter/RN/GL 混合架构卡顿**: detect_architecture → HWUI host skill + architecture-specific producer skill → 合并依赖判断
- **概览/场景还原**: scene_reconstruction → 按场景路由到对应 Skill
- **功耗/耗电**: wattson_rails_power_breakdown → wattson_thread_power_attribution；数据缺失时 battery_charge_timeline / android_kernel_wakelock_summary / suspend_wakeup_analysis fallback

也可以使用 `list_skills` 发现更多可用技能，或使用 `execute_sql` 做自定义查询。

#### 通用场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`slice_self_dur`、`cpu_utilization_in_interval(ts, dur)`、`cpu_frequency_counters`、`android_garbage_collection_events`、`android_oom_adj_intervals`、`android_screen_state`、`android_dvfs_counters`、`wattson_rails_aggregation`、`android_battery_charge`
<!-- /strategy-detail -->
