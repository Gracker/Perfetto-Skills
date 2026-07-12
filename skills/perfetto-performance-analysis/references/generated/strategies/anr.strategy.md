GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/anr.strategy.md
Source SHA-256: 7789a0289bed4a0b46c99ddcd9705bdf77585f0f349359d83f1bc1f84cbcc719
Source commit: 185f0ffb7335de511f608acc42f5752a0f6d7c1e

# Anr Strategy

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
scene: anr
priority: 1
effort: medium
required_capabilities:
- anr
- cpu_scheduling
optional_capabilities:
- binder_ipc
- lock_contention
- gc_memory
keywords:
- anr
- 无响应
- 应用无响应
- 主线程无响应
- deadlock
- not responding
- 死锁
- watchdog
- broadcast timeout
- input dispatching
- 冻屏
- freeze
- 卡死
compound_patterns:
- (ApplicationExitInfo|getHistoricalProcessExitReasons|ProfilingManager|ProfilingTrigger|Play Vitals|Android Vitals|client
  watchdog|SDK watchdog).*(ANR|not responding|无响应|卡死)
- (ANR|not responding|无响应|卡死).*(ApplicationExitInfo|getHistoricalProcessExitReasons|ProfilingManager|ProfilingTrigger|Play
  Vitals|Android Vitals|client watchdog|SDK watchdog)
final_report_contract:
  required_sections:
  - id: anr_diagnostic_api_boundary
    label: ANR 诊断 API/外部聚合边界
    description: 当用户主动提到 ApplicationExitInfo、ProfilingTrigger、Play/Android Vitals 或客户端 watchdog 时，区分系统确认 ANR、客户端预警、Profiling
      artifact、Play 聚合和当前 trace 根因证据。
    trigger_patterns:
    - ApplicationExitInfo|getHistoricalProcessExitReasons|getAnrInfo|REASON_ANR
    - ProfilingManager|ProfilingTrigger|TRIGGER_TYPE_ANR
    - Play Vitals|Android Vitals|user-perceived ANR|client watchdog|SDK watchdog
    pattern_groups:
    - - ANR 诊断 API/外部聚合边界
      - ANR diagnostic API
      - system-confirmed
      - client watchdog
      - Play Vitals
      - ProfilingTrigger
      - ApplicationExitInfo
    - - diagnostic_api
      - profiling_artifact
      - external_aggregate
      - ApplicationExitInfo
      - getAnrInfo
      - REASON_ANR
      - ProfilingManager
      - ProfilingTrigger
      - TRIGGER_TYPE_ANR
      - Play Vitals
      - Android Vitals
      - watchdog
    - - API\s*3[067]
      - Android\s*1[167]
      - version
      - 版本
      - reason
      - trigger type
      - timeout
      - ANR window
      - event window
      - timestamp
      - artifact
    - - current trace
      - Perfetto
      - direct_blocker
      - logcat
      - Binder
      - lock
      - align
      - 对齐
      - missing
      - 缺失
      - confidence
      - 不能
      - 不可
      - not replace
phase_hints:
- id: freeze_verdict
  keywords:
  - verdict
  - 判定
  - freeze
  - diagnosis
  - 诊断
  - 原因
  - anr_analysis
  - 系统
  - system
  constraints: freeze_verdict 是第一优先级门控。system freeze → 系统原因排查；app_specific → 进入 App 根因决策树（5 步子流程）。禁止在未确认 freeze_verdict 前直接分析
    App 代码。
  critical_tools:
  - anr_analysis
  critical: true
- id: anr_diagnostic_api_boundary
  keywords:
  - ApplicationExitInfo
  - getHistoricalProcessExitReasons
  - getAnrInfo
  - REASON_ANR
  - ProfilingManager
  - ProfilingTrigger
  - TRIGGER_TYPE_ANR
  - Play Vitals
  - Android Vitals
  - client watchdog
  - SDK watchdog
  constraints: ApplicationExitInfo、ProfilingTrigger 产物、Play/Android Vitals、客户端 watchdog 都只能补充 ANR 证据。必须说明 API/Android 版本、reason/trigger
    type、record/artifact 时间、事件窗口对齐；根因仍需 Perfetto ANR window、direct_blocker、logcat、Binder/lock/IO/GC/scheduler 证据闭环。
  critical_tools:
  - anr_analysis
  critical: false
plan_template:
  mandatory_aspects:
  - id: anr_root_cause
    match_keywords:
    - anr
    - deadlock
    - block
    - 死锁
    - 阻塞
    - not_responding
    - anr_analysis
    suggestion: ANR 场景建议包含 ANR 原因定位阶段 (anr_analysis)
    required_expected_calls:
    - skill_id: anr_analysis
```

#### anr Core Strategy

**Route card**: anr / 无响应 / 应用无响应 / 主线程无响应 / deadlock / not responding / 死锁 / watchdog / broadcast timeout / input dispatching

**Capabilities**: required=[anr, cpu_scheduling], optional=[binder_ipc, lock_contention, gc_memory]

**Final report contract summary**
- ANR 诊断 API/外部聚合边界


<!-- strategy-detail id="full" title="anr full strategy detail" keywords="anr,anr,无响应,应用无响应,主线程无响应,deadlock,not responding,死锁,watchdog,broadcast timeout,input dispatching,冻屏,freeze,ANR 分析（用户提到 ANR、无响应、not responding、死锁、冻屏）,detail,full" default="true" -->
#### ANR 分析（用户提到 ANR、无响应、not responding、死锁、冻屏）

**⚠️ 核心原则：**
1. **先判系统还是应用**：先读取 `system_freeze_check` step 保存的 `freeze_check.freeze_verdict`。系统冻屏导致的 ANR 不是 App Bug
2. **分清四层语义**：`trigger_type` 是触发机制，`direct_blocker` 是 ANR 窗口内的直接阻塞形态，`root_cause_pattern_hints` 只是候选提示，最终根因必须由多源证据闭环
3. **按 ANR 类型差异化分析**：INPUT_DISPATCHING / NO_FOCUS / BROADCAST / SERVICE / JOB / WATCHDOG / CONTENT_PROVIDER 的分析路径不同
4. **四象限 + blocked_functions 交叉定位根因**：与启动分析相同的诊断方法论
5. **量化证据链**：每个根因判断必须有窗口裁剪后的时长、线程状态占比、Binder 对端、锁 owner 或系统上下文等具体证据

### ANR 类型与超时阈值

| ANR 类型 | 超时阈值 | 触发条件 |
|----------|---------|---------|
| INPUT_DISPATCHING_TIMEOUT | 5s | 输入事件分发无响应 |
| INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW | 5s | 没有可接收输入的焦点窗口 |
| BROADCAST_OF_INTENT | 10s (前台) / 60s (后台) | BroadcastReceiver.onReceive() 超时 |
| START_FOREGROUND_SERVICE | Perfetto 默认 30s | 前台服务启动链路未及时完成 |
| EXECUTING_SERVICE | Perfetto 默认 20s（OEM/前后台策略可能不同） | Service.onCreate()/onStartCommand() 超时 |
| FOREGROUND_SERVICE_TIMEOUT / FOREGROUND_SHORT_SERVICE_TIMEOUT | Perfetto 默认 30s / 180s | 前台服务生命周期超时 |
| CONTENT_PROVIDER_NOT_RESPONDING | 可能无 Perfetto 默认值 | ContentProvider 发布或访问链路超时 |
| JOB_SERVICE_START / JOB_SERVICE_STOP / JOB_SERVICE_BIND | 8s 级别 | JobService 回调或绑定链路超时 |
| SYSTEM_SERVER_WATCHDOG_TIMEOUT | 系统 Watchdog | system_server Handler/锁/Binder 线程卡死 |
| GPU_HANG | 可能无 Perfetto 默认值 | GPU/fence/buffer 链路无响应 |
| APP_TRIGGERED | 可能无 Perfetto 默认值 | App 主动触发或厂商扩展 ANR |
| UNKNOWN_ANR_TYPE | 兜底 | 类型未知，先保留 baseline evidence |

#### 证据边界和裁剪规则

#### ANR 场景关键 Stdlib 表

写 execute_sql 时优先使用（完整列表见方法论模板）：`android_oom_adj_intervals`、`android_monitor_contention_chain`、`android_screen_state`、`sched_latency_for_running_interval`、`cpu_utilization_in_interval(ts, dur)`、`android_garbage_collection_events`

**Phase 1 — ANR 检测 + 系统健康评估（1 次调用）：**
- 如果知道包名，传入 `process_name` 或 `package` 参数
- 返回结果包含以下关键 artifact：
  - `detection`：ANR 检测（总数、受影响进程数、时间跨度）
  - `trigger_classification`：Perfetto ANR 类型到 the portable runtime `trigger_type` 的规范化映射，并输出候选根因提示（非最终结论）
  - `cpu_health`：系统 CPU 负载（大核/小核利用率、是否过载）
  - `memory_pressure`：ANR 窗口内的 LMK 事件
  - `io_load`：各进程的 D-state 不可中断等待基线；不能单独作为 IO 根因
  - `lock_waits`：futex/mutex 锁等待分布（P95/max）
  - **`freeze_check`**（from `system_freeze_check`）：**系统冻结判定（最关键）**
  - `overview` / `anr_events`：ANR 分类统计、逐事件窗口、`timeout_source` 与跳转范围
  - 逐 ANR 的 `anr_detail` 迭代结果（四象限、`direct_blocker_classification` 保存为 `direct_blocker_candidates`、`direct_blocker_slice_classification` 保存为 `direct_blocker_slice_candidates`、`anr_logcat_context` 保存为 `logcat_event_context`、Binder、锁竞争、唤醒链等）

**必须获取关键 artifact 的完整数据**：
优先获取：`freeze_check`、`trigger_classification`、`anr_events`、逐 ANR 的 `quadrant`（四象限）、`direct_blocker_candidates`（from `direct_blocker_classification`）、`direct_blocker_slice_candidates`（from `direct_blocker_slice_classification`，若 slice 可用）和 `logcat_event_context`（from `anr_logcat_context`）；若缺 `android_logs`，读取 `logcat_context_gap`（from `anr_logcat_evidence_gap`）。`blocking`/Binder/sched artifact 只作为包名级辅助上下文

**Phase 2 — 冻结判定分流（基于 freeze_verdict，第一优先级）：**

### ⚠️ 必须首先检查 `freeze_check.freeze_verdict` 字段：

| freeze_verdict | 含义 | 后续分析方向 |
|---------------|------|-------------|
| `system_server_freeze` | system_server 冻结（running_pct < 5%） | **系统级问题**：system_server watchdog、kernel panic、硬件故障。报告为系统问题，不是 App Bug |
| `system_freeze` | 多数应用冻结（frozen_pct > 70%）但 system_server 未冻结 | **系统级问题**：可能是 CPU 饥饿（thermal throttling、后台负载）、内存压力（大量 LMK）、IO 风暴。交叉检查 `cpu_health` 和 `memory_pressure` |
| `app_specific` | 仅目标应用受影响 | **应用级问题**：进入 Phase 3 详细分析主线程阻塞原因 |

**当 `freeze_verdict = system_server_freeze` 或 `system_freeze` 时：**
- 如果 `detection.total_anr_count === 1`：可报告为系统级问题，不要深入推测 App 代码；交叉检查 `cpu_health`、`memory_pressure`、`io_load` 和系统侧日志后到 Phase 4 输出
- 如果 `detection.total_anr_count > 1`：`freeze_check` 只代表首个 ANR 窗口 baseline context，不能直接推广到全部 ANR。必须继续读取逐 ANR `direct_blocker_candidates`、`direct_blocker_slice_candidates`、`logcat_event_context` 和 `app_freeze_check`，逐事件确认是否同属系统冻结链路
- 多 ANR 只有在每个关键事件窗口都有系统侧线程/日志/资源压力证据闭环时，才能升级为整体系统根因；否则按事件分别输出系统背景 + App/对端候选

**Phase 3 — App 级根因诊断决策树（当 freeze_verdict = app_specific）：**

### 第一步：看四象限分布（来自 anr_detail 的 `quadrant`）

### 第二步：当 Q4 占比高时 — 以 direct_blocker + 线程状态定位

先读取逐事件 `direct_blocker_candidates`（from `direct_blocker_classification`）。`blocking`（主线程状态分布）里的 `blocked_function` 可帮助理解状态，但它是包名级上下文，不能单独作为最终根因：

| 线程状态 | blocked_functions 特征 | 根因类型 | 典型场景 |
|---------|----------------------|---------|---------|
| S (Sleeping) | `futex_wait_queue` / `futex_wait` | **锁等待** | art_lock_contention、monitor 竞争、synchronized 块 |
| S (Sleeping) | `binder_wait_for_work` / `binder_ioctl` | **同步 Binder 阻塞** | 跨进程 IPC 等待 system_server/对端进程响应 |
| S (Sleeping) | `do_epoll_wait` / `ep_poll` | **Looper 空闲/等待事件** | 正常空闲等待（非阻塞，排除性证据） |
| S (Sleeping) | `pipe_wait` / `pipe_read` | **管道等待** | 等待子线程/进程通信 |
| S (Sleeping) | `SyS_nanosleep` / `hrtimer_nanosleep` | **主动 sleep** | Thread.sleep() 在主线程 |
| D (Uninterruptible sleep) + `io_wait=1` | `io_schedule` / `blkdev_issue_flush` | **IO wait 直接证据** | 大文件读写、SQLite 操作、存储队列等待 |
| D (Uninterruptible sleep) | `SyS_fsync` / `do_fsync` | **fsync 候选** | SQLite WAL checkpoint、SharedPreferences commit；需结合 DB/SP/file slice |
| D (Uninterruptible sleep) | `filemap_read` / `filemap_fault` / `do_page_fault` | **页缓存/页缺失候选** | 内存映射文件首次访问；需结合 page fault、block I/O 或内存压力 |
| D (Uninterruptible sleep) | 无明确 IO/page-fault blocked_function | **不可中断等待候选** | 低置信系统/内核等待信号，必须继续找 slice、blocked_function 或 block IO 证据 |

同时读取 `direct_blocker_candidates`（from `direct_blocker_classification`）：

| direct_blocker_type | 可直接说明什么 | 还缺什么才能定最终根因 |
|---------------------|---------------|------------------------|
| `binder_wait` | 主线程同步 Binder 等待 | 对端进程/服务端线程是否忙、死锁或系统卡顿 |
| `lock_or_futex_wait` | 主线程锁/monitor/futex 等待 | 锁 owner、monitor contention chain、持锁代码路径 |
| `disk_or_page_fault_io` / `db_or_file_io_slice` | 主线程或关键线程处于 IO/DB 路径 | IO 系统上下文、文件/SQLite 调用栈或 slice 名称 |
| `render_or_fence_wait` | RenderThread/SF/fence 候选 | SurfaceFlinger、buffer/fence 和 draw/focus 链证据 |
| `gc_or_stw_wait` | GC/STW 候选 | GC pause、内存压力、LMK 或 heap 变化 |
| `scheduler_pressure` | runnable 但调度不足 | sched_latency、CPU topology、后台进程抢占 |
| `native_poll_idle_or_ambiguous` | Looper/epoll 等待 | 只能说明空闲或证据不足，不能单独定因 |

### 第三步：按 ANR 类型差异化分析

当 blocked_functions 不足以确定根因时，结合 ANR 类型缩小范围：

| ANR 类型 | 重点检查 | 关键 artifact |
|----------|---------|-------------|
| INPUT_DISPATCHING_TIMEOUT | 主线程在做什么？是否有长 Binder 调用或锁等待阻塞了 input 处理 | `direct_blocker_candidates`、`lock_contention`、事件级 Logcat/InputDispatcher |
| INPUT_DISPATCHING_TIMEOUT_NO_FOCUSED_WINDOW | Activity/window 焦点链：resume 是否返回、relayout/draw 是否完成、WindowManager 是否给焦点；与 stale drop、InputChannel 失败和普通 `wq` FINISHED timeout 分开 | `trigger_classification`、`logcat_event_context`、`render_thread`、WindowManager/InputDispatcher 日志、dumpsys input/window |
| BROADCAST_OF_INTENT | `onReceive()` 内是否有网络/IO/数据库操作在主线程执行 | `direct_blocker_candidates`、`main_slices`（查找 onReceive 相关 slice）、事件级 ActivityManager/Broadcast 日志 |
| START_FOREGROUND_SERVICE / EXECUTING_SERVICE / FOREGROUND_SERVICE_TIMEOUT | Service 生命周期、前台服务启动和冷启动链路 | `direct_blocker_candidates`、`main_slices`、Service/ActivityManager 日志 |
| JOB_SERVICE_START / STOP / BIND | JobService 回调或绑定链路，不要简化成普通 Service | `direct_blocker_candidates`、`logcat_event_context`、事件级 JobScheduler 日志 |
| CONTENT_PROVIDER_NOT_RESPONDING | provider publish、query/CRUD 或跨进程 Provider 访问阻塞 | `direct_blocker_candidates`、`main_slices`、`io_load` |
| SYSTEM_SERVER_WATCHDOG_TIMEOUT | system_server Handler/锁/Binder 线程，默认不是 App Bug | `freeze_check`、system_server 线程状态、monitor contention |
| GPU_HANG | GPU/fence/buffer 或 RenderThread/SF 链路 | `render_thread`、SurfaceFlinger 日志、frame/fence slice |

### 第四步：进阶诊断工具（按需）

| 工具 | 何时使用 | artifact |
|------|---------|---------|
| **唤醒链（wakeup_chain）** | Q4 高但 blocked_function 为空时 — 谁唤醒了主线程？ | `wakeup` |
| **锁竞争（lock_contention）** | blocked_function 含 futex/monitor 时 — 谁持有锁？ | `lock_contention`（from `android_monitor_contention`） |
| **App 冻结检测（app_freeze_check）** | 判断应用是否完全无活动（MainThread+RenderThread+Binder 全部无活动） | 逐 ANR `app_freeze_check` |
| **RenderThread 分析** | INPUT_DISPATCHING_TIMEOUT 中，检查是否 nSyncDraw/dequeueBuffer 阻塞 | `render_thread` |
| **Binder 调用详情** | direct_blocker 为 binder_wait 时补查对端进程是谁；包名级 Binder artifact 只能补证 | `binder_calls`、`main_sync_binder` |
| **调度延迟** | Q3 Runnable 高且 direct_blocker 为 scheduler_pressure 时补查具体延迟分布 | `sched` |

### 第五步：交叉验证系统上下文

**Phase 4 — 综合输出：**

### 输出结构必须遵循：

1. **ANR 概览**：
   - ANR 事件数、受影响进程数、时间跨度
   - 系统冻结判定结果（`freeze_verdict`）+ system_server 状态
   - 如果是系统级问题，明确标注 **"⚠️ 系统级问题，非应用 Bug"**

2. **系统健康摘要**：
   - CPU 负载状态（正常/繁忙/过载）
   - 内存压力（LMK 事件数）
   - D-state 不可中断等待基线（Top 进程；不能单独写成 IO 根因）

3. **逐 ANR 根因分析**（每个 ANR 事件）：
   ```
   ### ANR #N: [进程名] — [ANR 类型] ([超时阈值])
  - **触发类型**：trigger_type=[input/no_focus/broadcast/service/job/watchdog/...]，timeout_source=[actual_anr_duration/perfetto_default/heuristic_fallback]
   - **四象限**：Q1=XX% Q2=XX% Q3=XX% Q4=XX% → 状态判断: [blocked/cpu_starved/busy_running]
   - **直接阻塞点**：direct_blocker=[binder_wait/lock_or_futex_wait/native_poll_idle_or_ambiguous/...]，证据时长=XXms，root_cause_boundary=[needs_peer_evidence/...]
   - **候选根因提示**：root_cause_pattern_hints=[deadlock/high_load_anr/memory_leak_oom_pressure/none]（明确标注为 not final）
   - **逐事件日志上下文**：logcat_event_context=[AnrManager/InputDispatcher/WindowManager/JobScheduler...]；如果 android_logs 不存在，列出 logcat_context_gap 证据缺口
   - **根因推理链**：
     ① 四象限显示 Q4=NN%（主线程大量时间被阻塞）
     ② 线程状态：S(Sleeping) = XXms，blocked_function = `futex_wait_queue` → 锁等待
     ③ 锁持有者：[线程名] 在执行 [操作]（来自 lock_contention）
     ④ 结论：[具体根因 + 证据]
   - **App 冻结状态**：[正常/部分冻结/完全冻结]
   - **Binder 影响**：[主线程同步 Binder 总时长、关键对端]
   ```

4. **优化建议**：
   - 按影响面排序
   - 区分系统侧 vs 应用侧建议
   - 系统冻屏：建议检查 system_server watchdog、thermal、内存压力
   - 应用锁等待：建议减少 synchronized 范围、使用异步 Binder
   - 应用 IO/page-cache 候选：先补齐 io_wait/blocked_function 与文件/数据库/Provider 证据，再建议将同步 IO 移到后台线程
   - CPU 饥饿：建议检查后台进程、调整线程优先级

⚠️ **禁止的做法：**
- 不检查 `freeze_verdict` 就开始分析 App 代码（可能把系统冻屏误判为 App Bug）
- 只说"主线程被阻塞"而不提供 blocked_function 和具体阻塞对象
- 忽略 `wakeup_chain` 数据（这是定位间接依赖链的关键）
- 把所有 ANR 统一用同一个决策路径分析，不区分 ANR 类型
- 忽略逐 ANR `app_freeze_check`（应用完全冻结 vs 部分响应是重要区分）
- 不交叉检查 CPU/内存/IO 系统上下文就下结论
- 把 `root_cause_pattern_hints`、AnrManager 文本或 `nativePollOnce` 当成最终根因
- 把 stale drop、no-focused-window、InputChannel 失败、`wq`/FINISHED timeout 混成同一种 input ANR 根因
- 多 ANR 场景中混用不同 `error_id` 的日志、Binder、锁竞争和调度证据
- 对 Binder/锁/CPU/IO/内存压力只给单点证据，不说明还缺的 peer/owner/system/context 证据
<!-- /strategy-detail -->
