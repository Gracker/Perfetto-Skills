GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/power.strategy.md
Source SHA-256: b9affc6a8fb4c4e2cce098a590bce85f44c468534aa9c4b0a5b765370fbf89cc
Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

# Power Strategy

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
scene: power
priority: 4
effort: medium
required_capabilities:
- cpu_scheduling
optional_capabilities:
- power_rails
- battery_counters
- cpu_freq_idle
- gpu_work_period
- thermal_throttling
- device_state
keywords:
- 功耗
- 耗电
- 电池
- 掉电
- 发热
- wattson
- power
- battery
- drain
- energy
- thermal
- allow-while-idle
- setExactAndAllowWhileIdle
- exact alarm
- wakeup alarm
- Android vitals
- partial wakelock
compound_patterns:
- 电池.*掉
- 耗电.*原因
- 功耗.*分析
- battery.*drain
- power.*analysis
- (JobScheduler|WorkManager|JobParameters|WorkInfo).*(quota|stop reason|pending reason|timeout|standby bucket|expedited|foreground
  worker|后台|耗电|power|battery)
- (quota|stop reason|pending reason|timeout|standby bucket|expedited).*(JobScheduler|WorkManager|JobParameters|WorkInfo)
- (Foreground Service|foreground service|\bFGS\b|dataSync|mediaProcessing|shortService).*(timeout|quota|battery|power|耗电|后台|前台服务|前景服务)
- (timeout|quota).*(Foreground Service|foreground service|\bFGS\b|dataSync|mediaProcessing|shortService)
- (UIDT|user[- ]initiated data transfer).*(transfer|job|quota|power|battery|耗电|后台)
- (allow[- ]while[- ]idle|setExactAndAllowWhileIdle|exact alarm|wakeup alarm|AlarmManager).*(battery|power|wake|wakeup|doze|idle|耗电|唤醒|待机)
- (wakelock|wake lock|partial wakelock|Vitals|excessive wakeups).*(background|battery|power|24h|2h|1h|stuck|excessive|耗电|后台|唤醒)
final_report_contract:
  required_sections:
  - id: job_work_fgs_governance_boundary
    label: Job/Work/FGS 治理边界
    description: 当问题涉及 JobScheduler、WorkManager、Foreground Service、UIDT 或 Android 16 quota 时，区分 trace 事件、app/API 诊断、pending
      reason、stop reason、版本/状态边界和缺失证据。
    trigger_patterns:
    - JobScheduler|WorkManager|Foreground Service|\bFGS\b|foreground worker|JobParameters|WorkInfo|UIDT|user[- ]initiated
      data transfer
    - pending\s+reason|stop\s+reason|getPendingJobReasons?|getPendingJobReasonStats|getStopReason|runtime\s+quota|job\s+quota|standby\s+bucket|expedited\s+job
    - Android\s*1[56].*(?:quota|foreground service|JobScheduler|WorkManager|FGS|timeout)
    - dataSync|mediaProcessing|shortService|Service\.onTimeout|前台服务|前景服务|后台任务|作业调度
    pattern_groups:
    - - Job/Work/FGS
      - JobScheduler
      - WorkManager
      - Foreground Service
      - \bFGS\b
      - UIDT
      - user[- ]initiated
      - 后台执行
      - background execution
    - - pending reason
      - stop reason
      - getPendingJobReason
      - getPendingJobReasons
      - getPendingJobReasonStats
      - getStopReason
      - runtime quota
      - job quota
      - \bquota\b
      - standby bucket
      - timeout
      - Service\.onTimeout
    - - trace
      - logcat
      - WorkInfo
      - JobParameters
      - dumpsys
      - app telemetry
      - 外部
      - missing
      - 缺失
      - 版本
      - Android\s*1[4567]
      - confidence
      - 置信度
      - 不能
      - 不可
  - id: alarm_wakeup_vitals_boundary
    label: Alarm/Wakeup/Vitals 边界
    description: 当问题涉及 AlarmManager、wakeup、allow-while-idle、wakelock 或 Android/Play Vitals 时，区分本地 trace 窗口、Alarm API/权限证据、24h
      聚合阈值和缺失数据。
    trigger_patterns:
    - allow[- ]while[- ]idle|setExactAndAllowWhileIdle|exact alarm|AlarmManager|wakeup alarm|excessive wakeups
    - wakelock|wake lock|partial wakelock|Android vitals|Play vitals|stuck partial|excessive partial|Vitals
    - \bwakeups?\b|唤醒
    pattern_groups:
    - - Alarm/Wakeup/Vitals
      - AlarmManager
      - exact alarm
      - allow[- ]while[- ]idle
      - setExactAndAllowWhileIdle
      - wakeup
      - wakeups?
      - wakelock
      - wake lock
      - partial wakelock
      - vitals
    - - 24h
      - 2h
      - 1h
      - one hour
      - two hours
      - observed window
      - trace window
      - 局部
      - 24\s*小时
      - 2\s*小时
      - 1\s*小时
      - 观测窗口
      - Play vitals
      - Android vitals
      - excessive
      - stuck
    - - trace
      - dumpsys alarm
      - android_wakeups
      - android_kernel_wakelock
      - external_aggregate
      - 外部聚合
      - missing
      - 缺失
      - permission
      - SCHEDULE_EXACT_ALARM
      - USE_EXACT_ALARM
      - 置信度
      - 不能
      - 不可
phase_hints:
- id: power_data_gate
  keywords:
  - power
  - battery
  - wattson
  - 功耗
  - 耗电
  - 电池
  - 数据
  - 采集
  constraints: 先检查 Trace 数据完整度中的 power_rails、battery_counters、cpu_freq_idle、gpu_work_period。缺失时必须输出数据采集建议，禁止把空表解释为“没有功耗问题”。需要总览时优先调用
    power_consumption_overview；拆开看时先调用 power_rails_energy_breakdown 和 battery_drain_rate_summary。
  critical_tools:
  - power_consumption_overview
  - power_rails_energy_breakdown
  - battery_drain_rate_summary
  critical: true
- id: wattson_attribution
  keywords:
  - wattson
  - rail
  - thread
  - 归因
  - 能耗
  - energy
  - power_rails
  constraints: Wattson 是估算，不是 ODPM 实测。只有 power_rails/cpu_freq_idle 数据可用时才用 Wattson 归因。先用 power_rails_energy_breakdown 看硬件
    rail，再用 wattson_rails_power_breakdown / wattson_thread_power_attribution 做 CPU/线程估算；启动窗口问题再加 wattson_app_startup_power。
  critical_tools:
  - wattson_rails_power_breakdown
  - wattson_thread_power_attribution
  - wattson_app_startup_power
  critical: false
- id: battery_drain_chain
  keywords:
  - battery drain
  - standby drain
  - 掉电
  - 待机耗电
  - 后台耗电
  - wakelock
  - doze
  - job
  - network
  constraints: 用户问掉电/待机耗电时优先调用 battery_drain_attribution，把 battery drain rate、Doze、suspend/wakeup、wakelock、screen-off CPU、job、network
    串起来；缺 rail 数据时只能给事件链归因。
  critical_tools:
  - battery_drain_attribution
  - wakeup_frequency_summary
  - screen_off_background_cpu_attribution
  - modem_network_correlation_summary
  critical: false
- id: background_execution_governance
  keywords:
  - JobScheduler
  - WorkManager
  - Foreground Service
  - FGS
  - foreground worker
  - UIDT
  - pending reason
  - stop reason
  - runtime quota
  - standby bucket
  - expedited job
  - dataSync
  - mediaProcessing
  - shortService
  constraints: 后台执行治理必须把 JobScheduler pending reason（为何未运行）与 JobParameters/WorkInfo stop reason（为何停止）分开。Perfetto 的 job event
    只能证明执行窗口；Android 15/16 quota、FGS timeout、UIDT 和 standby bucket 结论必须标注版本、target/app state、app 日志/API 或 dumpsys 证据缺口。
  critical_tools:
  - battery_drain_attribution
  - android_job_scheduler_events
  - android_kernel_wakelock_summary
  - battery_doze_state_timeline
  - screen_off_background_cpu_attribution
  - suspend_wakeup_analysis
  critical: false
- id: alarm_wakeup_boundary
  keywords:
  - AlarmManager
  - exact alarm
  - allow-while-idle
  - setExactAndAllowWhileIdle
  - wakeup alarm
  - wakeups
  - wakelock
  - partial wakelock
  - Android vitals
  - Play vitals
  - excessive wakeups
  constraints: Alarm/wakeup 只能从本地 trace 证明唤醒、wakelock、suspend/Doze 现象；不能仅凭 wakeup 反推 AlarmManager API、exact-alarm 权限或 Play
    Vitals 违规。Vitals 需要 24h/聚合窗口，短 trace 只能写局部参考。
  critical_tools:
  - wakeup_frequency_summary
  - suspend_wakeup_analysis
  - android_kernel_wakelock_summary
  - battery_drain_attribution
  critical: false
- id: thermal_chain
  keywords:
  - thermal
  - throttling
  - 发热
  - 温控
  - 降频
  - 热节流
  - gpu work period
  - mali
  constraints: 用户问发热、降频、热导致卡顿时优先调用 thermal_throttling_chain；同时说明温度传感器/DVFS/GPU work period 哪些数据存在，哪些缺失。
  critical_tools:
  - thermal_throttling_chain
  critical: false
- id: fallback_state_power
  keywords:
  - wakelock
  - doze
  - battery
  - dvfs
  - thermal
  - 唤醒
  - 待机
  - 降频
  constraints: 如果 Wattson 前置数据缺失，退化为状态/事件链分析：battery_drain_rate_summary、battery_charge_timeline、battery_doze_state_timeline、wakeup_frequency_summary、android_kernel_wakelock_summary、screen_off_background_cpu_attribution、android_dvfs_counter_stats、suspend_wakeup_analysis。结论必须标注这是定性分析，不是
    rail 级能耗归因。
  critical_tools:
  - battery_drain_rate_summary
  - battery_charge_timeline
  - battery_doze_state_timeline
  - wakeup_frequency_summary
  - android_kernel_wakelock_summary
  - screen_off_background_cpu_attribution
  - android_dvfs_counter_stats
  - suspend_wakeup_analysis
  critical: false
plan_template:
  mandatory_aspects:
  - id: power_data_availability
    match_keywords:
    - power
    - battery
    - wattson
    - 功耗
    - 耗电
    - 电池
    - 数据完整度
    - 采集
    suggestion: 功耗场景必须先确认 power_rails/battery_counters/cpu_freq_idle/gpu_work_period 是否可用
    required_expected_call_alternatives:
    - skill_id: power_rails_energy_breakdown
    - skill_id: battery_charge_timeline
    - skill_id: android_dvfs_counter_stats
    - skill_id: android_gpu_work_period_track
  - id: power_attribution_or_fallback
    match_keywords:
    - wattson
    - rail
    - thread
    - wakelock
    - doze
    - 归因
    - 唤醒
    - 降频
    suggestion: 功耗场景需要包含 Wattson 归因或状态事件 fallback 分析阶段
    required_expected_call_alternatives:
    - skill_id: wattson_thread_power_attribution
    - skill_id: wattson_rails_power_breakdown
    - skill_id: wakelock_tracking
    - skill_id: device_state_timeline
  - id: power_composite_entrypoint
    match_keywords:
    - power_consumption_overview
    - battery_drain_attribution
    - thermal_throttling_chain
    - 总览
    - 掉电
    - 温控链路
    suggestion: 复杂功耗问题建议先用 power_consumption_overview / battery_drain_attribution / thermal_throttling_chain 建立统一证据链
    required_expected_call_alternatives:
    - skill_id: power_consumption_overview
    - skill_id: battery_drain_attribution
    - skill_id: thermal_throttling_chain
  - id: power_vitals_threshold_context
    match_keywords:
    - wakelock
    - vitals
    - excessive
    - stuck
    - P90
    - P99
    - 后台
    suggestion: Wakelock 阈值必须说明时间基准：24h 累计 >=2h excessive，单后台 wakelock >=1h stuck，P90/P99 >60min 重点排查；短 trace 只能作为局部证据或换算参考
    required_expected_call_alternatives:
    - skill_id: wakelock_tracking
    - {}
```

#### power Core Strategy

**Route card**: 功耗 / 耗电 / 电池 / 掉电 / 发热 / wattson / power / battery / drain / energy

**Capabilities**: required=[cpu_scheduling], optional=[power_rails, battery_counters, cpu_freq_idle, gpu_work_period, thermal_throttling, device_state]

**Final report contract summary**
- Job/Work/FGS 治理边界
- Alarm/Wakeup/Vitals 边界


<!-- strategy-detail id="full" title="power full strategy detail" keywords="power,功耗,耗电,电池,掉电,发热,wattson,power,battery,drain,energy,thermal,allow-while-idle,功耗 / 电池 / Wattson 分析（用户提到 功耗、耗电、电池、掉电、wattson）,detail,full" default="true" -->
#### 功耗 / 电池 / Wattson 分析（用户提到 功耗、耗电、电池、掉电、wattson）

功耗分析的第一原则：**先判数据能不能支撑结论**。Wattson/rail 级归因依赖 `android.power`、power rails、CPU freq/idle、GPU work period 等采集源。缺失这些数据时，不能把空结果解释为“没有耗电”；只能输出采集建议，或退化为状态/事件链分析。

#### 功耗场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_power_rails_counters`、`android_power_rails_metadata`、`wattson_rails_aggregation!(window)`、`wattson_threads_aggregation!(window)`、`wattson_window_app_startup`、`android_battery_charge`、`android_screen_state`、`android_deep_idle_state`、`android_wakeups`、`android_kernel_wakelocks`、`android_network_packets`、`android_network_uptime_spans!`、`android_dvfs_counter_stats`、`android_gpu_work_period_track`、`cpu_idle_counters`、`cpu_frequency_counters`

#### 固定执行顺序

1. **数据完整度**：先判断 `power_rails` / `battery_counters` / `cpu_freq_idle` / `gpu_work_period` 是否可用。
2. **全局量纲**：优先用 `power_rails_energy_breakdown` 看硬件 rail 实测 mWh，再用 `battery_drain_rate_summary` 看 trace 窗口掉电趋势。
3. **待机健康度**：screen-off / standby 问题必须看 `suspend_wakeup_analysis` 和 `wakeup_frequency_summary`，再看 `android_kernel_wakelock_summary`。
4. **后台执行治理**：JobScheduler / WorkManager / FGS / UIDT / Alarm / Wakelock 要分清 trace 事件、app/API 日志、dumpsys、Play/Vitals 聚合和 Android 版本政策；不能把本地事件直接写成平台治理结论。
5. **归因链路**：CPU 用 `screen_off_background_cpu_attribution` / `wattson_thread_power_attribution` / `cpu_freq_residency_summary`；网络只用 `modem_network_correlation_summary` 做 correlation；GPU/温控再走 GPU/thermal 链。
6. **可信度分层**：结论必须标注 `hardware_power_rails` / `wattson_estimate` / `battery_counter_trend` / `event_chain_fallback` / `external_policy_or_aggregate` / `insufficient_data`。

#### Wakelock / Vitals 阈值语义

- partial wakelock 24h 累计 >= 2h：Android vitals excessive 参考阈值。
- 单个后台 partial wakelock >= 1h：stuck wakelock 参考阈值。
- P90/P99 > 60min：重点排查。
- Android vitals 只在 app 后台或前台服务持有 partial wakelock 时计入，并存在音频、位置、JobScheduler user-initiated 等豁免；the portable runtime 的单条 trace 通常不是 24h 数据。除非 trace 覆盖完整统计周期或用户提供 Play/Vitals 聚合数据，否则只能输出“局部证据 / 换算参考 / 需长期采样确认”，不能直接判定 Play vitals 违规。

**Phase 0 — 数据完整度门禁：**

先读取系统提示中的 Trace 数据完整度结果：

| capability | 缺失时含义 | 处理 |
|---|---|---|
| `power_rails` | 无 rail 级能耗估算 | 不调用 Wattson rail/thread 能耗结论；输出 `collect_power_rails` 采集建议 |
| `battery_counters` | 无电量/电流采样 | 不计算掉电速率；输出 `battery_poll_ms` 采集建议 |
| `cpu_freq_idle` | 无 CPU idle/freq 完整状态 | 不做 Wattson CPU 能耗归因；可退化为 CPU 频率/DVFS 定性分析 |
| `gpu_work_period` | 无 GPU active region | 不做 GPU work period/能耗归因；可退化为 GPU 频率或 Mali power state 分析 |

如果用户明确问“怎么采集”，优先调用：

**Phase 1 — Wattson rail/thread 归因（数据可用时）：**

复杂功耗问题优先使用总览入口：

需要拆开看时再调用：

分析顺序：
1. 看 rail 总能耗排序：CPU/GPU/DDR/Modem 哪个是主耗能源
2. 看线程级归因：是否是目标 App 线程、system_server、RenderThread、Binder 线程池或后台进程消耗
3. 如果能耗集中在某一时间窗口，结合 `cpu_thread_utilization_period` / `cpu_process_utilization_period` 做 CPU 利用率交叉验证

**Phase 2 — 启动期功耗（用户提到启动耗电时）：**


把启动窗口能耗与启动类型、进程创建、CPU/DVFS 状态关联。不能只给总能耗，必须说明能耗集中在哪个阶段或线程。

**Phase 3 — 电池/Doze/Wakelock fallback（Wattson 数据缺失或用户问待机耗电时）：**

掉电/待机耗电优先使用组合入口：

需要拆开看时再调用：

输出要明确标注：这是状态/事件链证据，能说明“是否频繁唤醒、是否无法进入 Doze、是否有 wakelock”，但不是 rail 级功耗量化。

**Phase 3.5 — 后台执行治理证据（按需）：**

当用户提到 JobScheduler、WorkManager、Foreground Service/FGS、UIDT、quota、pending reason、stop reason、AlarmManager、allow-while-idle、wakeup 或 Android vitals 时，在功耗归因前先做治理边界拆分：


报告必须分清这些证据面：

| 证据面 | 能证明什么 | 不能直接证明什么 |
|---|---|---|
| `android_job_scheduler_events` | JobScheduler 执行窗口、服务名、包名、UID | pending reason、stop reason、quota 触发原因、WorkManager worker 业务语义 |
| `JobScheduler#getPendingJobReason(s)` / dumpsys / app 日志 | Job 为什么未运行：constraint、quota、standby bucket、background restriction 等候选原因 | 已运行任务为何停止 |
| `JobParameters.getStopReason()` / `WorkInfo.getStopReason()` / app telemetry | 正在运行的 Job/Worker 为什么停止：timeout、quota、constraint、device state、background restriction 等 | 未运行任务的完整等待历史；未来 Android 版本可能新增 reason |
| FGS logcat / service telemetry | `dataSync`、`mediaProcessing`、`shortService` timeout 或 `Service.onTimeout()` 路径 | 没有服务日志时，不能只凭 CPU/Job trace 认定 FGS timeout |
| `android_wakeups` / wakelock / suspend / Doze | 本地 trace 窗口内是否唤醒频繁、阻止 suspend、Doze 状态异常 | 具体 AlarmManager API、exact alarm 权限、Play Vitals 24h 聚合违规 |

版本/政策边界：

- Android 15：`dataSync` / `mediaProcessing` FGS 在后台 24h 内共享各自 6h budget，超限后系统调用 `Service.onTimeout(int, int)`；`shortService` 是更短的约 3 分钟路径。没有 Android 版本、targetSdk、service type 或 logcat/API 证据时，只能写“版本敏感候选”。
- Android 16：JobScheduler regular/expedited runtime quota 会受 standby bucket、top/visible 起始状态、FGS 并发影响；WorkManager、JobScheduler、DownloadManager 都会受影响。FGS 并发不再是 Job quota 豁免证据。
- UIDT：Android 14+ 的 user-initiated data transfer 是长耗时用户触发传输的边界；trace 只能看到 Job/网络/CPU 现象，是否 UIDT 需要 JobInfo/API 或 app 日志。
- Alarm / allow-while-idle：wakeup trace 只能证明设备被唤醒；exact alarm、`setExactAndAllowWhileIdle`、`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` 权限和 Android 17 listener API 需要 app/API/dumpsys 证据。

**Phase 4 — GPU/温控/频率交叉验证（按需）：**

温控/降频/发热导致性能问题时优先：

**输出结构：**

1. **数据完整度判定**：power_rails / battery_counters / cpu_freq_idle / gpu_work_period 哪些可用，哪些缺失
2. **全局能量/掉电趋势**：硬件 rail mWh、Wattson 估算 mWh、battery drain rate 分开列
3. **待机健康度**：suspend 占比、wakeup/min、wakelock Top、screen-off CPU 是否异常
4. **时间窗口关联**：耗电/唤醒/降频发生在什么阶段，是否与启动、滑动、后台任务、网络活动重叠
5. **后台执行治理边界**（仅相关时）：Job pending reason vs stop reason、WorkManager/JobScheduler/FGS/UIDT、Alarm/wakeup/Vitals 的证据来源、版本边界和缺失数据
6. **结论可信度**：hardware_power_rails / wattson_estimate / battery_counter_trend / event_chain_fallback / external_policy_or_aggregate / insufficient_data
7. **采集建议**：缺哪些数据就给具体 Perfetto 配置方向，不泛泛而谈；CLI 可建议 `smp capture android --preset power --app <pkg> --duration <sec>`
<!-- /strategy-detail -->
