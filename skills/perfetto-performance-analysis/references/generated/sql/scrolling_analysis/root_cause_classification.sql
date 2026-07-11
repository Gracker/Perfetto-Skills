-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH
-- 双信号混合掉帧检测（与 performance_summary/get_app_jank_frames 保持同口径）
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config AS (
  SELECT CASE
    WHEN raw_ns BETWEEN 5500000 AND 6500000 THEN 6060606
    WHEN raw_ns BETWEEN 6500001 AND 7500000 THEN 6944444
    WHEN raw_ns BETWEEN 7500001 AND 9500000 THEN 8333333
    WHEN raw_ns BETWEEN 9500001 AND 12500000 THEN 11111111
    WHEN raw_ns BETWEEN 12500001 AND 20000000 THEN 16666667
    WHEN raw_ns BETWEEN 20000001 AND 35000000 THEN 33333333
    ELSE raw_ns
  END AS vsync_period_ns
  FROM (
    SELECT CAST(COALESCE(
      (SELECT PERCENTILE(interval_ns, 0.5)
       FROM vsync_intervals
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
-- 掉帧检测：双信号混合策略
frame_jank_data AS (
  SELECT
    a.ts as frame_start,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as frame_end,
    a.upid,
    p.pid,
    p.name as process_name,
    a.jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as prev_present_ts,
    a.ts - LAG(a.ts + a.dur)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as time_gap_ns,
    CASE
      WHEN a.jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 'APP'
      WHEN a.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN a.jank_type = 'Buffer Stuffing' THEN 'BUFFER_STUFFING'
      WHEN a.jank_type = 'None' OR a.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
token_gap_jank AS (
  SELECT
    -- 感知掉帧总数：双信号混合检测
    SUM(CASE
      WHEN present_type IN ('Late Present', 'Dropped Frame')
        AND jank_type != 'Buffer Stuffing' THEN 1
      WHEN jank_type = 'Buffer Stuffing'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config) * 6
        AND (time_gap_ns IS NULL OR time_gap_ns <= (SELECT vsync_period_ns FROM vsync_config) * 6) THEN 1
      ELSE 0 END) as total_jank_count,
    -- App 侧掉帧（BS 帧的 jank_type 不可能是 Self Jank/App Deadline Missed/App Resynced Jitter）
    SUM(CASE WHEN present_type IN ('Late Present', 'Dropped Frame')
      AND jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 1 ELSE 0 END) as app_jank_count,
    SUM(CASE WHEN present_type IN ('Late Present', 'Dropped Frame')
      AND jank_type GLOB '*SurfaceFlinger*' THEN 1 ELSE 0 END) as sf_jank_count
  FROM frame_jank_data
),
jank_frame_windows AS (
  SELECT
    frame_start,
    frame_end,
    upid,
    pid,
    process_name
  FROM frame_jank_data
  WHERE jank_responsibility IN ('APP', 'HIDDEN')
    AND (
      (present_type IN ('Late Present', 'Dropped Frame') AND (jank_type IS NULL OR jank_type != 'Buffer Stuffing'))
      OR (
        jank_type = 'None'
        AND prev_present_ts IS NOT NULL
        AND present_ts - prev_present_ts > (SELECT vsync_period_ns FROM vsync_config) * 1.5
        AND present_ts - prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config) * 6
        AND (time_gap_ns IS NULL OR time_gap_ns <= (SELECT vsync_period_ns FROM vsync_config) * 6)
      )
    )
),
app_frames AS (
  SELECT
    COUNT(*) as total_frames,
    SUM(CASE WHEN jank_type != 'None' THEN 1 ELSE 0 END) as app_reported_jank,
    AVG(CASE WHEN dur > 0 THEN dur ELSE NULL END) / 1e6 as avg_dur_ms,
    MAX(CASE WHEN dur > 0 THEN dur ELSE NULL END) / 1e6 as max_dur_ms
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
jank_stats AS (
  SELECT
    (SELECT total_frames FROM app_frames) as total_frames,
    (SELECT app_reported_jank FROM app_frames) as app_reported_jank,
    COALESCE((SELECT app_jank_count FROM token_gap_jank), 0) as app_jank,
    COALESCE((SELECT sf_jank_count FROM token_gap_jank), 0) as sf_jank,
    COALESCE((SELECT sf_jank_count FROM token_gap_jank), 0) as buffer_jank,
    (SELECT avg_dur_ms FROM app_frames) as avg_dur_ms,
    (SELECT max_dur_ms FROM app_frames) as max_dur_ms,
    ROUND((SELECT vsync_period_ns FROM vsync_config) / 1e6, 2) as frame_budget_ms
),
-- 主线程四象限分析
main_thread_analysis AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_big_core_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_small_core_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_runnable_ns,
    SUM(CASE WHEN ts.state IN ('S', 'D', 'DK', 'I') THEN ts.dur ELSE 0 END) as q4_sleep_ns,
    SUM(ts.dur) as total_dur_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND t.tid = p.pid
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
-- RenderThread 分析
render_thread_analysis AS (
  SELECT
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('prime', 'big') THEN ts.dur ELSE 0 END) as q1_big_core_ns,
    SUM(CASE WHEN ts.state = 'Running' AND COALESCE(ct.core_type, 'unknown') IN ('medium', 'little') THEN ts.dur ELSE 0 END) as q2_small_core_ns,
    SUM(CASE WHEN ts.state = 'R' THEN ts.dur ELSE 0 END) as q3_runnable_ns,
    SUM(CASE WHEN ts.state IN ('S', 'D', 'DK', 'I') THEN ts.dur ELSE 0 END) as q4_sleep_ns,
    SUM(ts.dur) as total_dur_ns
  FROM thread_state ts
  JOIN thread t ON ts.utid = t.utid
  JOIN process p ON t.upid = p.upid
  LEFT JOIN _cpu_topology ct ON ts.cpu = ct.cpu_id
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND t.name = 'RenderThread'
    AND (${start_ts} IS NULL OR ts.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
),
-- 计算主线程各象限百分比
main_pct AS (
  SELECT
    ROUND(100.0 * q1_big_core_ns / NULLIF(total_dur_ns, 0), 1) as q1_pct,
    ROUND(100.0 * q2_small_core_ns / NULLIF(total_dur_ns, 0), 1) as q2_pct,
    ROUND(100.0 * q3_runnable_ns / NULLIF(total_dur_ns, 0), 1) as q3_pct,
    ROUND(100.0 * q4_sleep_ns / NULLIF(total_dur_ns, 0), 1) as q4_pct
  FROM main_thread_analysis
),
-- 计算 RenderThread 各象限百分比
render_pct AS (
  SELECT
    ROUND(100.0 * q1_big_core_ns / NULLIF(total_dur_ns, 0), 1) as q1_pct,
    ROUND(100.0 * q2_small_core_ns / NULLIF(total_dur_ns, 0), 1) as q2_pct,
    ROUND(100.0 * q3_runnable_ns / NULLIF(total_dur_ns, 0), 1) as q3_pct,
    ROUND(100.0 * q4_sleep_ns / NULLIF(total_dur_ns, 0), 1) as q4_pct
  FROM render_thread_analysis
),
-- Input 阶段 slice 统计（用于 enable_frame_details 结论面）。
-- 仅统计 App/HIDDEN 掉帧帧窗口内、主线程上的 input slice，避免把无关长 slice
-- 误归因为最终根因。
input_stage_overlaps AS (
  SELECT
    jfw.frame_start,
    s.name,
    MAX(MIN(s.ts + s.dur, jfw.frame_end) - MAX(s.ts, jfw.frame_start), 0) as overlap_ns
  FROM jank_frame_windows jfw
  JOIN thread t ON t.upid = jfw.upid
    AND (t.tid = jfw.pid OR t.name GLOB '[0-9]*.ui')
  JOIN thread_track tt ON tt.utid = t.utid
  JOIN slice s ON s.track_id = tt.id
    AND s.ts < jfw.frame_end
    AND s.ts + s.dur > jfw.frame_start
    AND s.dur >= 100000
  WHERE s.name GLOB '*deliverInputEvent*'
    OR s.name GLOB '*processInputEventForCompatibility*'
    OR s.name GLOB '*dispatchTouchEvent*'
    OR s.name GLOB '*onInterceptTouchEvent*'
    OR s.name GLOB '*onTouchEvent*'
    OR s.name GLOB '*InputConsumer*'
    OR s.name GLOB '*RV Prefetch*'
    OR s.name GLOB '*RecyclerView*Prefetch*'
),
input_stage_stats AS (
  SELECT
    COUNT(*) as total_input_slices,
    SUM(CASE
      WHEN overlap_ns > (SELECT vsync_period_ns FROM vsync_config) * ${input_handling_budget_ratio|0.5}
      THEN 1 ELSE 0 END) as slow_input_slices,
    MAX(overlap_ns) / 1e6 as max_input_slice_ms,
    AVG(overlap_ns) / 1e6 as avg_input_slice_ms
  FROM input_stage_overlaps
  WHERE overlap_ns > 0
),
-- Binder 调用统计
binder_stats AS (
  SELECT
    COUNT(*) as total_calls,
    SUM(client_dur) / 1e6 as total_dur_ms,
    MAX(client_dur) / 1e6 as max_dur_ms,
    AVG(client_dur) / 1e6 as avg_dur_ms
  FROM android_binder_txns
  WHERE (client_process GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR client_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR client_ts < ${end_ts})
),
-- 综合分析
analysis AS (
  SELECT
    (SELECT total_frames FROM jank_stats) as total_frames,
    (SELECT app_jank FROM jank_stats) as app_jank,
    (SELECT sf_jank FROM jank_stats) as sf_jank,
    (SELECT buffer_jank FROM jank_stats) as buffer_jank,
    (SELECT avg_dur_ms FROM jank_stats) as avg_dur_ms,
    (SELECT max_dur_ms FROM jank_stats) as max_dur_ms,
    (SELECT frame_budget_ms FROM jank_stats) as frame_budget_ms,
    (SELECT q3_pct FROM main_pct) as main_q3_pct,
    (SELECT q4_pct FROM main_pct) as main_q4_pct,
    (SELECT q2_pct FROM main_pct) as main_q2_pct,
    (SELECT q4_pct FROM render_pct) as render_q4_pct,
    (SELECT total_dur_ms FROM binder_stats) as binder_total_ms,
    (SELECT max_dur_ms FROM binder_stats) as binder_max_ms,
    (SELECT total_input_slices FROM input_stage_stats) as total_input_slices,
    (SELECT slow_input_slices FROM input_stage_stats) as slow_input_slices,
    (SELECT max_input_slice_ms FROM input_stage_stats) as input_max_slice_ms,
    (SELECT avg_input_slice_ms FROM input_stage_stats) as input_avg_slice_ms
)
SELECT
  -- 问题分类: APP / SYSTEM / MIXED
  CASE
    WHEN (SELECT sf_jank FROM analysis) > (SELECT app_jank FROM analysis) * 2 THEN 'SYSTEM'
    WHEN (SELECT app_jank FROM analysis) > (SELECT sf_jank FROM analysis) * 2 THEN 'APP'
    WHEN (SELECT main_q3_pct FROM analysis) > 15 THEN 'SYSTEM'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 AND (SELECT binder_max_ms FROM analysis) > 5 THEN 'MIXED'
    WHEN (SELECT slow_input_slices FROM analysis) > 0 THEN 'APP'
    WHEN (SELECT app_jank FROM analysis) > 0 THEN 'APP'
    ELSE 'UNKNOWN'
  END as problem_category,
  -- 问题组件
  -- 注意：MAIN_THREAD_BLOCKING (休眠/阻塞) 与 MAIN_THREAD (耗时操作) 是互斥的
  -- Q4 > 30% 表示主线程大部分时间在等待，问题是"阻塞"
  -- 只有 Q4 <= 30% 且 avg_dur 超过当前 VSync 预算，才判定为"主线程耗时操作"
  CASE
    WHEN (SELECT sf_jank FROM analysis) > (SELECT app_jank FROM analysis) * 2 THEN 'SURFACE_FLINGER'
    WHEN (SELECT main_q3_pct FROM analysis) > 15 THEN 'CPU_SCHEDULING'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 AND (SELECT binder_max_ms FROM analysis) > 5 THEN 'BINDER'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 THEN 'MAIN_THREAD_BLOCKING'
    WHEN (SELECT slow_input_slices FROM analysis) > 0 THEN 'INPUT_HANDLING'
    WHEN (SELECT render_q4_pct FROM analysis) > 50 THEN 'RENDER_THREAD'
    WHEN (SELECT main_q2_pct FROM analysis) > 50 THEN 'CPU_AFFINITY'
    WHEN (SELECT avg_dur_ms FROM analysis) > COALESCE((SELECT frame_budget_ms FROM analysis), 8.33)
         AND COALESCE((SELECT main_q4_pct FROM analysis), 0) <= 30 THEN 'MAIN_THREAD'
    ELSE 'UNKNOWN'
  END as problem_component,
  -- 置信度 (0-1)
  CASE
    WHEN (SELECT total_frames FROM analysis) < 10 THEN 0.3
    WHEN (SELECT sf_jank FROM analysis) > (SELECT app_jank FROM analysis) * 2 THEN 0.9
    WHEN (SELECT app_jank FROM analysis) > (SELECT sf_jank FROM analysis) * 2 THEN 0.85
    WHEN (SELECT main_q3_pct FROM analysis) > 20 THEN 0.8
    WHEN (SELECT main_q4_pct FROM analysis) > 40 THEN 0.8
    WHEN (SELECT slow_input_slices FROM analysis) > 0 THEN 0.8
    ELSE 0.6
  END as confidence,
  -- 根因总结
  CASE
    WHEN (SELECT sf_jank FROM analysis) > (SELECT app_jank FROM analysis) * 2 THEN
      '系统级问题: SurfaceFlinger 处理异常，导致 ' || (SELECT sf_jank FROM analysis) || ' 帧掉帧'
    WHEN (SELECT main_q3_pct FROM analysis) > 15 THEN
      '系统级问题: CPU 调度拥堵，主线程 ' || (SELECT main_q3_pct FROM analysis) || '% 时间在等待调度'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 AND (SELECT binder_max_ms FROM analysis) > 5 THEN
      '跨进程阻塞: Binder 调用最大耗时 ' || ROUND((SELECT binder_max_ms FROM analysis), 1) || 'ms'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 THEN
      '主线程阻塞: ' || (SELECT main_q4_pct FROM analysis) || '% 时间在休眠/等待'
    WHEN (SELECT slow_input_slices FROM analysis) > 0 THEN
      '输入处理阻塞: ' || (SELECT slow_input_slices FROM analysis) || ' 个输入阶段 slice 超过帧预算阈值，最长相关 slice ' || ROUND((SELECT input_max_slice_ms FROM analysis), 1) || 'ms'
    WHEN (SELECT render_q4_pct FROM analysis) > 50 THEN
      'RenderThread 等待: ' || (SELECT render_q4_pct FROM analysis) || '% 时间在休眠'
    WHEN (SELECT main_q2_pct FROM analysis) > 50 THEN
      'CPU 亲和性问题: 主线程 ' || (SELECT main_q2_pct FROM analysis) || '% 时间运行在小核'
    WHEN (SELECT app_jank FROM analysis) > 0 THEN
      '应用级问题: ' || (SELECT app_jank FROM analysis) || ' 帧因应用原因掉帧，平均帧耗时 ' || ROUND((SELECT avg_dur_ms FROM analysis), 1) || 'ms'
    ELSE
      '分析数据不足，建议查看详细帧数据'
  END as root_cause_summary,
  -- 证据列表 (JSON 数组)
  '[' ||
    '"总帧数: ' || (SELECT total_frames FROM analysis) || '",' ||
    '"App 掉帧: ' || (SELECT app_jank FROM analysis) || '",' ||
    '"SF 掉帧: ' || (SELECT sf_jank FROM analysis) || '",' ||
    '"主线程 Q3 (等待调度): ' || COALESCE((SELECT main_q3_pct FROM analysis), 0) || '%",' ||
    '"主线程 Q4 (休眠阻塞): ' || COALESCE((SELECT main_q4_pct FROM analysis), 0) || '%",' ||
    '"慢输入阶段 slice: ' || COALESCE((SELECT slow_input_slices FROM analysis), 0) || '",' ||
    '"Binder 最大耗时: ' || COALESCE(ROUND((SELECT binder_max_ms FROM analysis), 1), 0) || 'ms"' ||
  ']' as evidence,
  -- 优化建议
  CASE
    WHEN (SELECT sf_jank FROM analysis) > (SELECT app_jank FROM analysis) * 2 THEN
      '检查系统负载和 SurfaceFlinger 状态'
    WHEN (SELECT main_q3_pct FROM analysis) > 15 THEN
      '减少后台任务，考虑提高主线程优先级'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 AND (SELECT binder_max_ms FROM analysis) > 5 THEN
      '优化 Binder 调用，考虑异步化或缓存'
    WHEN (SELECT main_q4_pct FROM analysis) > 30 THEN
      '检查主线程阻塞原因 (IO/锁/Binder)'
    WHEN (SELECT slow_input_slices FROM analysis) > 0 THEN
      '避免在 dispatchTouchEvent/onTouchEvent/onScrollChanged 中执行耗时同步逻辑，必要时拆分到后台或下一帧'
    WHEN (SELECT render_q4_pct FROM analysis) > 50 THEN
      '优化绘制流程，减少主线程耗时操作'
    WHEN (SELECT main_q2_pct FROM analysis) > 50 THEN
      '考虑使用 setThreadAffinity 或提高线程优先级'
    ELSE
      '查看详细帧分析，定位具体问题'
  END as suggestion
