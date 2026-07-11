GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/interaction.strategy.md
Source SHA-256: c3eb61bf5806cf14412a5e75372d408bba284d73b7a970718e9b2a0032cd7cde
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Interaction Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### interaction Core Strategy

**Route card**: 点击 / 触摸 / 输入延迟 / 响应延迟 / 点击慢 / 响应慢 / 点击卡顿 / click / tap / touch

**Capabilities**: required=[input_latency, frame_rendering], optional=[cpu_scheduling, binder_ipc, surfaceflinger]





**Phase reminders**
- input_ack_queue_boundary: 先区分 completed android.input 事件的 dispatch/handling/ACK 总耗时与未完成 FINISHED 的队列背压。wq 增长只能说明目标连接尚未 ACK；必须结合 App 主线程、InputDispatcher、dumpsys/logcat 或窗口证据，不能直接命名 Binder、App 代码或 InputDispatcher 根因。 工具: click_response_analysis, click_response_detail, input_events_in_range
- focus_window_stale_boundary: stale drop、no-focused-window、InputChannel 创建/断连和 target-window 选择是不同对象。trace 只含 completed input events 时要写成证据缺口；需要 WindowManager/InputDispatcher logcat、dumpsys input 或窗口拓扑证据才能定因。 工具: input_events_in_range
- display_present_boundary: total_latency_dur 是 dispatch-to-ACK，不是 input-to-present。只有 end_to_end_latency_dur、frame_id/FrameTimeline、RenderThread/SF present 证据可用时，才能写上屏或可见反馈延迟；否则只报告 dispatch/ACK 或首帧候选。 工具: click_response_analysis, input_to_frame_latency, scroll_response_latency

**Final report contract summary**
- 输入阶段拆分
- ACK/焦点/窗口边界
- 置信度与缺失证据


**Detail ref**
- `interaction:full`: 点击/触摸响应分析（用户提到 点击、触摸、tap、click、input latency） 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="interaction full strategy detail" keywords="interaction,点击,触摸,输入延迟,响应延迟,点击慢,响应慢,点击卡顿,click,tap,touch,input latency,response time,点击/触摸响应分析（用户提到 点击、触摸、tap、click、input latency）,detail,full" default="true" -->
#### 点击/触摸响应分析（用户提到 点击、触摸、tap、click、input latency）



**Phase 2 — 逐事件深钻（最多 5 个慢事件）：**



对大型 artifact 使用 `fetch_artifact` 获取完整行数据。

**Phase 3 — 综合结论（基于根因决策树）：**

### 第一步：瓶颈定位 — dispatch vs handling vs ACK / display

| 延迟阶段 | 含义 | 高占比（>50% 总延迟）时的根因方向 |
|---------|------|-------------------------------|
| dispatch_ms | 系统分发延迟（InputDispatcher 到目标 App receive 之前） | 系统侧或目标唤醒问题：system_server/InputDispatcher 调度、InputChannel/socket、目标窗口选择或进程唤醒；需要 system_server/窗口/logcat/dumpsys 交叉验证 |
| handling_ms | 应用处理延迟（应用收到事件到处理完成） | 应用侧问题：主线程阻塞、计算量大 → 用四象限分析定位 |
| ack_ms | FINISHED/ACK 延迟（处理回调完成到 finish/ack 写回及调度） | 可能是回调尾部、调度或 writeback 延迟；不是帧上屏证据 |
| display/present | 输入到可见反馈（需要 `end_to_end_latency_dur`、`frame_id`/FrameTimeline、RenderThread/SF present） | 只有帧/上屏链路可用时才归因渲染或 SurfaceFlinger；缺失时写成数据缺口 |

### 输入队列、焦点和窗口边界（只在有证据时定因）

- `iq` / `oq:{window}` / `wq:{window}` 分别代表 inbound、outbound 和 wait queue。`wq` 持续增长只说明该连接还没有收到 `FINISHED`，不能单独证明 Binder、App 业务代码或 InputDispatcher 是根因。
- stale event 是保护性丢弃旧事件，不是 App 已消费，也不等同 Input ANR。必须结合 stale/drop 日志、队列状态和前序窗口/线程时间线。
- Touch 目标来自 touched-window hit testing，Key 目标来自 focused-window resolution。WindowInfosListener / WMS 窗口拓扑证据影响 target/focus 判断，但不说明 App handling 耗时。
- InputChannel 创建失败、fd/内存耗尽或 dead channel 是窗口/通道生命周期问题，可能表现为窗口添加失败、缺焦点或 no-focused-window ANR；不要把它写成普通慢事件处理。
- 短 `deliverInputEvent` 只说明 App-side receive/process slice 短，不能排除事件在主线程 MessageQueue 中等待或更早的 dispatcher/channel/focus 延迟。

### 第二步：当 handling 是瓶颈时 — 用四象限分析定位

| 四象限 | 占比 | 含义 | 下一步 |
|--------|------|------|--------|
| Q1 大核运行 高 | >50% | CPU-bound，处理逻辑重 | 分析主线程热点 slice，检查是否有不必要的同步计算 |
| Q2 小核运行 高 | >15% | 被调度到性能不足的小核 | 检查进程优先级、EAS/uclamp 配置 |
| Q3 Runnable 高 | >5% | CPU 资源争抢 | 看调度延迟、后台负载 |
| Q4 Sleeping 高 | >25% | 主线程被阻塞 | **必须看 blocked_functions** → 第三步 |

### 第三步：当 Q4 占比高时 — 用线程状态 + blocked_functions 定位

| 线程状态 | blocked_functions 特征 | 根因类型 |
|---------|----------------------|---------|
| S (Sleeping) | `futex_wait_queue` / `futex_wait` | 锁等待（synchronized/ReentrantLock） |
| S (Sleeping) | `binder_wait_for_work` / `binder_ioctl` | 同步 Binder 阻塞 |
| S (Sleeping) | `SyS_nanosleep` / `hrtimer_nanosleep` | 主动 sleep() 调用 |
| D (Uninterruptible sleep) + `io_wait=1` | `io_schedule` / `blkdev_issue_flush` | IO wait 直接证据 |
| D (Uninterruptible sleep) | `SyS_fsync` / `do_fsync` | fsync 候选（SQLite/SharedPreferences 需 slice 补证） |
| D (Uninterruptible sleep) | `filemap_read` / `filemap_fault` / `do_page_fault` | 页缓存/页缺失候选 |

遇到 D-state、`io_wait` 或 blocked_function 时调用 `lookup_knowledge("thread-state-blocked-reason")`，说明 blocked_function 是 kernel wchan 单帧而不是完整调用栈。

### 第四步：多手势类型识别（次要 — 仅在用户明确提及时分析）

以下手势类型属于进阶分析，仅在用户明确提到"长按"、"双击"等手势关键词时才进行分析：

| 手势类型 | 识别方式 | 分析要点 |
|---------|---------|---------|
| **长按 (Long Press)** | ACTION_DOWN 到 ACTION_UP 之间持续时间 > 500ms，且无 MOVE 事件（或 MOVE < 3 次） | 长按响应由 ViewConfiguration.getLongPressTimeout() 控制（默认 500ms）。如果用户反馈长按响应慢，检查：① 主线程在 DOWN 后 500ms 内是否有阻塞导致 Looper 延迟处理 LongPress Runnable；② onLongClick 回调本身的执行耗时 |
| **双击 (Double Tap)** | 两次 ACTION_DOWN 之间间隔 < 300ms（ViewConfiguration.getDoubleTapTimeout()） | 双击检测由 GestureDetector 处理。如果用户反馈双击不灵敏，检查：① 两次 tap 间隔是否接近 300ms 阈值；② 首次 tap 的 ACTION_UP 处理是否过慢导致第二次 DOWN 被错过 |

**长按事件检测 SQL（仅在用户提及时使用）：**
```
execute_sql("WITH motion AS (SELECT read_time AS ts, event_action, process_name, SUM(CASE WHEN event_action='DOWN' THEN 1 ELSE 0 END) OVER (ORDER BY read_time) AS gid FROM android_input_events WHERE event_type='MOTION'), gestures AS (SELECT gid, MIN(ts) AS down_ts, MAX(CASE WHEN event_action='UP' THEN ts END) AS up_ts, COUNT(CASE WHEN event_action='MOVE' THEN 1 END) AS move_cnt FROM motion WHERE gid>0 GROUP BY gid) SELECT printf('%d', down_ts) AS ts, ROUND((up_ts - down_ts)/1e6, 1) AS hold_ms FROM gestures WHERE up_ts IS NOT NULL AND (up_ts - down_ts) > 500000000 AND move_cnt <= 2 ORDER BY down_ts LIMIT 20")
```

**双击事件检测 SQL（仅在用户提及时使用）：**
```
execute_sql("WITH downs AS (SELECT read_time AS ts, LAG(read_time) OVER (ORDER BY read_time) AS prev_ts FROM android_input_events WHERE event_type='MOTION' AND event_action='DOWN') SELECT printf('%d', ts) AS ts, ROUND((ts - prev_ts)/1e6, 1) AS gap_ms FROM downs WHERE prev_ts IS NOT NULL AND (ts - prev_ts) < 300000000 ORDER BY ts LIMIT 20")
```

### 输出结构必须遵循：

1. **概览**：总事件数、慢事件数、平均/P90/P99 延迟、总体评级
   - 如果无慢事件：报告"已完成 ACK 的输入事件响应良好"并说明它不覆盖未完成 ACK、stale drop、focus/window 或 InputChannel 证据

2. **瓶颈分布**：
   - dispatch-heavy 事件 N 个（系统侧）
   - handling-heavy 事件 N 个（应用侧）
   - ack-heavy 事件 N 个（FINISHED/ACK 回写或调度）
   - input-to-present / FrameTimeline 是否可用；不可用时不要写上屏延迟

3. **逐事件根因**（每个慢事件）：
   ```
   ### 事件 #N: [event_type] [event_action] — 总延迟 XXms
   - 瓶颈阶段：handling (XXms, YY%)
   - 四象限：Q1=XX% Q2=XX% Q3=XX% Q4=XX%
   - 根因：[具体根因 + blocked_functions 证据]
   - 建议：[可操作的优化建议]
   ```

4. **优化建议**：按影响面排序，区分系统侧 vs 应用侧建议

5. **证据边界**：列出 `android.input` completed-event、InputDispatcher/dumpsys/logcat、WindowManager/focus、FrameTimeline/present 哪些可用，哪些缺失；对 `wq`、stale、focus/window、InputChannel 只在证据闭环时定因。
<!-- /strategy-detail -->
