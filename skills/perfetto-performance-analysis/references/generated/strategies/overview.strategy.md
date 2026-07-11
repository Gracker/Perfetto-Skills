GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/overview.strategy.md
Source SHA-256: d1f0a9709bfbbd2b23c454880808291924601ff32775333643fcb29d1c298168
Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

# Overview Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### overview Core Strategy

**Route card**: 发生了什么 / 有什么问题 / 概览 / 整体分析 / 场景还原 / 场景分析 / what happened / overview / analyze the trace / scene reconstruction

**Capabilities**: required=[cpu_scheduling, device_state], optional=[frame_rendering, startup, binder_ipc, gc_memory, thermal_throttling, power_rails, battery_counters]





**Phase reminders**
- 无额外 phase hint。

**Final report contract summary**
- 遵循通用输出契约。


**Detail ref**
- `overview:full`: 概览 / 场景还原分析（用户提到 发生了什么、概览、overview、场景还原） 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="overview full strategy detail" keywords="overview,发生了什么,有什么问题,概览,整体分析,场景还原,场景分析,what happened,overview,analyze the trace,scene reconstruction,全局分析,概览 / 场景还原分析（用户提到 发生了什么、概览、overview、场景还原）,detail,full" default="true" -->
#### 概览 / 场景还原分析（用户提到 发生了什么、概览、overview、场景还原）

本策略将 trace 当作一段用户操作的"故事"来解读：先检测发生了哪些场景，再对有问题的场景做针对性深钻。



**必须获取关键 artifact 的完整数据**：
```
fetch_artifact(artifactId, detail="rows", offset=0, limit=50)
```
优先获取：`launches`、`gestures`、`inertial_scrolls`、`janks`、`timeline`

**Phase 2 — 问题分级（基于阈值判断）：**

对检测到的每个场景，按以下阈值判断是否存在性能问题：

| 场景类型 | 问题阈值 | 数据来源 |
|---------|---------|---------|
| cold_start | duration > 1000ms | launches artifact |
| warm_start | duration > 600ms | launches artifact |
| hot_start | duration > 200ms | launches artifact |
| scroll / inertial_scroll | jank_frames > 0 | janks artifact |
| tap | total latency > 200ms | gestures artifact |
| long_press | duration > 500ms | gestures artifact |
| power / wakelock | wakelock/Doze/battery 状态异常 | Trace 数据完整度 + power/battery skills |

按严重程度排序，选取 **top 3** 问题场景进入深钻。
如果所有场景都在阈值内，报告"trace 中未检测到明显性能问题"并给出各场景的关键指标。

**Phase 3 — 针对性深钻（路由表）：**

对每个问题场景，调用对应的 Skill 进行深钻：

如果深钻需要 `process_name`，系统会在进程级 Skill 执行前自动做身份准入和参数重写。若准入返回 ambiguous/blocked，调用 `process_identity_resolver` 查看候选进程；后续 Skill 的 `process_name` 使用 `recommended_process_name_param`，报告中的应用身份使用 `canonical_package_name`。

| 场景类型 | 调用的 Skill | 关键参数 |
|---------|------------|---------|
| cold_start / warm_start / hot_start | `startup_analysis` | （自动检测启动事件） |
| scroll / inertial_scroll | `scrolling_analysis` | start_ts, end_ts, process_name |
| tap | `click_response_analysis` | start_ts, end_ts, package, enable_per_event_detail=false |
| 有 jank 的时间区间 | `scrolling_analysis` | start_ts, end_ts, process_name |
| 耗电/唤醒/待机异常 | `battery_charge_timeline` / `android_kernel_wakelock_summary` / `suspend_wakeup_analysis` | start_ts, end_ts |

**不需要深钻的场景类型**（仅在时间线中描述即可）：
- idle：空闲时段（信息性）
- app_switch：前台切换（信息性）
- screen_on / screen_off：屏幕状态变化（信息性）

每个深钻只取概览级别结果（fetch summary artifact），不做逐帧/逐事件详细分析——本策略的目标是全局视角，用户可以对感兴趣的场景发起后续查询做深入分析。

**Phase 4 — 综合输出（叙事式时间线）：**

### 输出结构必须遵循：

1. **Trace 概览**：
   - 时间范围、总时长、前台应用、设备状态
   - 一句话总结：这段 trace 记录了什么操作

2. **时间线叙事**（按时间顺序描述用户操作场景）：
   ```
   [0.0s - 1.2s] 冷启动 com.example.app — 耗时 1200ms (超过 1000ms 阈值)
   [1.2s - 3.5s] 空闲等待
   [3.5s - 8.2s] 列表滑动 — 检测到 12 帧卡顿 (P90 掉帧 2 VSync)
   [8.2s - 8.8s] 点击操作 — 响应延迟 350ms (超过 200ms 阈值)
   [8.8s - 10.0s] 空闲
   ```

3. **问题场景诊断**（每个深钻的场景）：
   ```
   ### [严重程度] 场景: [场景类型] — [关键指标]
   - 时间范围：[start_ts] — [end_ts]
   - 关键发现：[来自深钻 Skill 的概览级结论]
   - 初步根因：[基于深钻数据的根因方向]
   ```

4. **Top 3 建议**：按影响面排序的优化建议

5. **建议后续分析**：
   - 如果启动慢："可以问'分析启动性能'获取详细根因"
   - 如果滑动卡顿："可以问'分析滑动卡顿'获取逐帧分析"
   - 如果点击慢："可以问'分析点击响应'获取逐事件分析"
<!-- /strategy-detail -->
