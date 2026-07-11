GENERATED FILE - DO NOT EDIT.
Source: backend/strategies/scroll-response.strategy.md
Source SHA-256: 8a21157416c0175602c7366081b6c506bb21eb45f608c793011a8b8c4cfc87ad
Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

# Scroll Response Strategy

Portable methodology extracted from the SmartPerfetto strategy library.

#### scroll_response Core Strategy

**Route card**: 滑动响应 / 滑动延迟 / 响应速度 / 首帧延迟 / 首帧响应 / scroll response / scroll latency / first frame / response latency / 滑动开始

**Capabilities**: required=[frame_rendering, input_latency], optional=[cpu_scheduling, surfaceflinger]





**Phase reminders**
- scroll_latency_scope_boundary: 先声明响应口径：dispatch-to-ACK、ACTION_MOVE 到首帧候选、还是 input-to-present。scroll_response_latency 的默认输出不能在缺少 FrameTimeline/present 链接时被写成硬端到端上屏。 工具: input_events_in_range, scroll_response_latency
- scroll_input_target_boundary: 滑动响应异常可能来自输入队列、窗口目标、stale drop 或未完成 ACK。若没有 dumpsys/logcat/WindowManager/InputDispatcher 证据，只能作为缺口，不要把它归因成 App 滑动代码。 工具: input_events_in_range

**Final report contract summary**
- 响应延迟口径
- 输入目标与队列边界
- FrameTimeline/上屏置信度


**Detail ref**
- `scroll_response:full`: 滑动响应速度分析（用户提到 滑动响应、滑动延迟、首帧延迟、scroll response、scroll latency） 的完整 phase recipe、SQL、fetch_artifact 表、决策树和边界说明。


<!-- strategy-detail id="full" title="scroll_response full strategy detail" keywords="scroll_response,滑动响应,滑动延迟,响应速度,首帧延迟,首帧响应,scroll response,scroll latency,first frame,response latency,滑动开始,scroll start,initial response,滑动响应速度分析（用户提到 滑动响应、滑动延迟、首帧延迟、scroll response、scroll latency）,detail,full" default="true" -->
#### 滑动响应速度分析（用户提到 滑动响应、滑动延迟、首帧延迟、scroll response、scroll latency）

**核心区分：滑动响应速度 ≠ 滑动流畅性**
- **响应速度**（本策略）：ACTION_MOVE → 第一帧候选反馈，或在有 FrameTimeline/present 链接时的 input-to-present 延迟（target: <100ms）
- **流畅性**（scrolling 策略）：持续滑动中的帧间稳定性 → 应使用 scrolling 策略

如果用户问的是持续滑动中的卡顿/掉帧，应引导到 scrolling 策略，而非本策略。

先声明本次使用的延迟口径：`total_latency_dur` 是 dispatch-to-ACK；`scroll_response_latency` 默认是 MOVE dispatch 到首帧开始的候选响应；只有 `end_to_end_latency_dur`、`frame_id`/FrameTimeline 或 RenderThread/SF present 可用时，才能写成 input-to-present / 上屏延迟。

**Phase 1 — 输入事件定位：**



如果该 Skill 不可用，使用 SQL 回退：
```sql
SELECT
  printf('%d', s.ts) AS ts,
  printf('%d', s.dur) AS dur,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  s.arg_set_id,
  EXTRACT_ARG(s.arg_set_id, 'event_action') AS action,
  EXTRACT_ARG(s.arg_set_id, 'event_type') AS type
FROM slice s
WHERE s.name = 'aq:pending:deliver'
  OR s.name GLOB 'deliverInputEvent*'
  OR s.name GLOB '*InputEvent*'
ORDER BY s.ts
LIMIT 50
```

- 找到滑动手势中 **ACTION_DOWN 之后的第一个 ACTION_MOVE** 事件
- 记录其时间戳作为 `gesture_start_ts`
- 如果有多个滑动手势，分别分析每个手势的首帧响应

**Phase 2 — 首帧关联：**



如果该 Skill 不可用，使用 SQL 回退：
```sql
-- 查找 gesture_start_ts 之后的第一帧
SELECT
  printf('%d', a.ts) AS frame_ts,
  printf('%d', a.dur) AS frame_dur,
  ROUND(a.dur / 1e6, 2) AS frame_dur_ms,
  printf('%d', a.ts + a.dur) AS present_ts,
  a.jank_type,
  a.on_time_finish
FROM actual_frame_timeline_slice a
LEFT JOIN process p ON a.upid = p.upid
WHERE p.name GLOB '{process_name}*'
  AND a.ts >= {gesture_start_ts}
ORDER BY a.ts
LIMIT 1
```

计算首帧候选响应延迟；只有 `present_ts` 可信且与输入事件/帧关联时，才写成上屏延迟：
```
response_latency = frame_present_ts - gesture_start_ts
```

**评级标准：**

| 响应延迟 | 评级 | 说明 |
|---------|------|------|
| <50ms | 极佳 | 用户几乎无感知延迟 |
| 50-100ms | 良好 | 在可接受范围内 |
| 100-200ms | 一般 | 用户可感知到轻微延迟 |
| 200-500ms | 差 | 明显卡顿感 |
| >500ms | 极差 | 严重影响用户体验 |

**Phase 3 — 延迟分解：**

将响应延迟按证据可见的段落分解，逐段定位瓶颈。缺少 present 或 frame linkage 时，不要补出不存在的上屏段：

**段 1：Input dispatch latency（内核 → App 进程）**
```sql
-- 查找输入事件分发耗时
SELECT
  printf('%d', s.ts) AS ts,
  ROUND(s.dur / 1e6, 2) AS dispatch_ms
FROM slice s
WHERE s.name = 'aq:pending:deliver'
  AND s.ts <= {gesture_start_ts} + 50000000  -- 50ms window
  AND s.ts >= {gesture_start_ts} - 10000000
ORDER BY s.ts
LIMIT 5
```

**段 2：Choreographer wait（收到输入 → 下一个 VSync doFrame）**
- 输入事件到达 App 后，需要等待下一个 VSync 信号触发 Choreographer#doFrame
- 正常等待 0-16ms（一个 VSync 周期）

**段 3：App frame build（measure + layout + draw）**
```sql
SELECT
  printf('%d', s.ts) AS ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  s.name AS slice_name
FROM slice s
WHERE s.name IN ('Choreographer#doFrame', 'measure', 'layout', 'draw', 'Record View#draw()')
  AND s.ts >= {gesture_start_ts}
  AND s.ts <= {gesture_start_ts} + 200000000  -- 200ms window
ORDER BY s.ts
LIMIT 20
```

**段 4：Render thread（sync + draw commands + swap buffers）**
```sql
SELECT
  printf('%d', s.ts) AS ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  s.name AS slice_name
FROM slice s
WHERE s.name IN ('DrawFrame', 'syncFrameState', 'flush commands', 'eglSwapBuffersWithDamageKHR')
  AND s.ts >= {gesture_start_ts}
  AND s.ts <= {gesture_start_ts} + 200000000
ORDER BY s.ts
LIMIT 20
```

**段 5：SurfaceFlinger composition（合成 + present）**
```sql
SELECT
  printf('%d', s.ts) AS ts,
  ROUND(s.dur / 1e6, 2) AS dur_ms,
  s.name AS slice_name
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
WHERE t.name = 'surfaceflinger'
  AND s.name IN ('onMessageReceived', 'INVALIDATE', 'REFRESH')
  AND s.ts >= {gesture_start_ts}
  AND s.ts <= {gesture_start_ts} + 200000000
ORDER BY s.ts
LIMIT 20
```

对每一段，判断耗时是否超出正常范围，定位瓶颈段。

**Phase 4 — 根因与建议：**

| 延迟段 | 正常范围 | 异常时根因方向 |
|--------|---------|-------------|
| Input dispatch | <10ms | system_server 负载高、input 线程被阻塞、InputChannel/socket、target/focused window 或输入管线积压 |
| Choreographer wait | 0-16ms（1 VSync） | 错过当前 VSync、要等下一个周期，可能主线程正忙 |
| App frame build | <8ms | 主线程忙（layout 复杂、数据加载、同步 Binder 阻塞） |
| Render thread | <4ms | GPU 负载高、draw commands 多、纹理上传 |
| SF composition | <4ms | GPU composition 慢、layer 数多、HWC 回退 |

**深钻决策（基于瓶颈段）：**



**输入目标与队列边界：**
- `input_events_in_range` / `scroll_response_latency` 只覆盖完成 dispatch→receive→finish→ACK 的事件。没有结果不等于没有输入问题，可能是未完成 ACK、stale drop、focus/window 或 InputChannel 证据缺失。
- `stale`、`focused window`、`target window`、`iq/oq/wq`、`FINISHED` 需要 dumpsys input、logcat、WindowManager/InputDispatcher 或窗口拓扑证据；缺失时写成数据缺口。
- 如果只有 ACTION_MOVE 到首帧候选，不要把它推广为真实 panel present 或 HWC 输出。

### 输出结构必须遵循：

1. **响应延迟口径**：说明使用 dispatch-to-ACK、ACTION_MOVE-to-first-frame，还是 input-to-present；给出总延迟（ms）+ 评级
   - 如有多个滑动手势，分别报告每个手势的首帧响应

2. **延迟分解瀑布图**：
   ```
   | 延迟段 | 耗时 | 占比 | 是否瓶颈 |
   |-------|------|------|---------|
   | Input dispatch | 5ms | 5% | |
   | Choreographer wait | 12ms | 12% | |
   | App frame build | 65ms | 65% | ★ 瓶颈 |
   | Render thread | 8ms | 8% | |
   | SF composition | 10ms | 10% | |
   | **总计** | **100ms** | **100%** | |
   ```

3. **瓶颈段根因分析**：
   - 具体到导致延迟的 Slice/函数/线程状态
   - 如果是主线程阻塞，给出 blocked_function 和 thread_state

4. **与滑动流畅性的关联**：
   - 如果首帧慢且后续帧也有卡顿 → 说明是系统性问题（如 CPU 频率不足、主线程持续被阻塞）
   - 如果仅首帧慢 → 可能是冷启动代价（首次布局/数据加载）

5. **优化建议**：按瓶颈段给出可操作的建议

6. **证据边界**：列出 FrameTimeline/present、InputDispatcher/dumpsys/logcat、WindowManager/focus、stale/FINISHED ACK 哪些可用，哪些缺失或不适用。
<!-- /strategy-detail -->
