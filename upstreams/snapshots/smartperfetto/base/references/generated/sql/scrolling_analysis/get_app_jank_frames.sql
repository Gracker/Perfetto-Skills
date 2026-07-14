-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH
-- VSync 周期（限定在分析区间内，避免 VRR 省电时段干扰）
vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
timing_config AS (
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
-- Per-layer 帧序列：按 layer_name 分组，计算 token gap + 时间 gap
layer_frames AS (
  SELECT
    a.display_frame_token,
    COALESCE(a.display_frame_token, a.surface_frame_token) as frame_token,
    a.ts,
    a.dur,
    a.upid,
    a.layer_name,
    a.jank_type,
    a.jank_severity_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    -- Per-layer token gap：SF 跳过了多少个 DisplayFrame 没有消费该 layer 的 buffer
    a.display_frame_token - LAG(a.display_frame_token)
      OVER (PARTITION BY a.layer_name ORDER BY a.display_frame_token) AS token_gap,
    -- 时间 gap（会话切分用）
    a.ts - LAG(a.ts + a.dur)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) AS time_gap_ns,
    -- present_ts（vsync_missed 严重度估算 + 报告展示用）
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END AS present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) AS prev_present_ts
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT
    *,
    CASE WHEN time_gap_ns IS NULL OR time_gap_ns > (SELECT vsync_period_ns * 6 FROM timing_config) THEN 1 ELSE 0 END as new_session
  FROM layer_frames
),
sessions_map AS (
  SELECT
    *,
    SUM(new_session) OVER (PARTITION BY layer_name ORDER BY ts) as session_id
  FROM session_markers
),
-- Per-layer 掉帧检测：双信号混合策略
-- 非 BS 帧：present_type IN ('Late Present', 'Dropped Frame')
-- BS 帧：间隔 > 1.5x vsync = 真实掉帧（被 BS 掩盖的卡顿）
jank_frames AS (
  SELECT
    sm.frame_token as frame_id,
    sm.display_frame_token,
    sm.upid,
    sm.ts as actual_start,
    sm.ts + sm.dur as actual_end,
    sm.dur as actual_dur,
    sm.jank_type,
    sm.jank_severity_type,
    sm.layer_name,
    sm.session_id,
    -- token_gap 保留用于信息展示
    sm.token_gap,
    -- vsync_missed：用 present_ts 间隔估算严重度（辅助信号）
    CASE
      WHEN sm.prev_present_ts IS NOT NULL AND sm.present_ts - sm.prev_present_ts > tc.vsync_period_ns * 1.5
        THEN MAX(CAST(ROUND((sm.present_ts - sm.prev_present_ts) * 1.0 / tc.vsync_period_ns - 1, 0) AS INTEGER), 0)
      ELSE 1  -- at least 1 vsync missed if present_type is Late/Dropped
    END as vsync_missed,
    -- 责任归属
    CASE
      WHEN sm.jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 'APP'
      WHEN sm.jank_type GLOB '*SurfaceFlinger*' THEN 'SF'
      WHEN sm.jank_type = 'Buffer Stuffing' THEN 'BUFFER_STUFFING'
      WHEN sm.jank_type = 'None' OR sm.jank_type IS NULL THEN 'HIDDEN'
      ELSE 'UNKNOWN'
    END as jank_responsibility,
    -- 消费端呈现间隔（毫秒）— 报告展示用
    ROUND((sm.present_ts - COALESCE(sm.prev_present_ts, sm.present_ts)) / 1e6, 2) as present_interval_ms,
    -- 隐形掉帧标记
    CASE WHEN sm.jank_type = 'None' OR sm.jank_type IS NULL THEN 1 ELSE 0 END as is_hidden_jank
  FROM sessions_map sm
  CROSS JOIN timing_config tc
  WHERE (
    -- 非 BS：present_type 为权威信号
    (sm.present_type IN ('Late Present', 'Dropped Frame') AND sm.jank_type != 'Buffer Stuffing')
    OR
    -- BS + 异常间隔：真实掉帧被 BS 掩盖
    (sm.jank_type = 'Buffer Stuffing'
     AND sm.prev_present_ts IS NOT NULL
     AND (sm.present_ts - sm.prev_present_ts) > tc.vsync_period_ns * 1.5
     AND (sm.present_ts - sm.prev_present_ts) <= tc.vsync_period_ns * 6)
  )
  -- 排除会话间断帧
  AND (sm.time_gap_ns IS NULL OR sm.time_gap_ns <= tc.vsync_period_ns * 6)
),
-- Guilty frame 溯源：找到导致缓冲区枯竭的慢帧
-- BlastBufferQueue 三缓冲下，可见卡顿发生在慢帧 2-3 帧之后
guilty_frame_candidates AS (
  SELECT
    jf.frame_id AS starvation_frame_id,
    prev.display_frame_token AS candidate_id,
    prev.ts AS candidate_start,
    prev.dur AS candidate_dur,
    prev.jank_type AS candidate_jank_type,
    CASE WHEN prev.dur > tc.vsync_period_ns THEN 1 ELSE 0 END AS is_slow,
    ROUND((prev.dur - tc.vsync_period_ns) / 1e6, 2) AS over_budget_ms,
    ROW_NUMBER() OVER (
      PARTITION BY jf.frame_id
      ORDER BY prev.dur DESC
    ) AS guilt_rank
  FROM jank_frames jf
  CROSS JOIN timing_config tc
  JOIN sessions_map prev
    ON prev.layer_name = jf.layer_name
    AND prev.session_id = jf.session_id
    AND prev.display_frame_token IS NOT NULL
    AND prev.display_frame_token >= jf.display_frame_token - 5
    AND prev.display_frame_token < jf.display_frame_token
    AND prev.dur > 0
  WHERE jf.display_frame_token IS NOT NULL
),
guilty_frames AS (
  SELECT
    starvation_frame_id,
    candidate_id AS guilty_frame_id,
    candidate_start AS guilty_start,
    candidate_dur AS guilty_dur,
    candidate_jank_type AS guilty_jank_type,
    over_budget_ms
  FROM guilty_frame_candidates
  WHERE guilt_rank = 1 AND is_slow = 1
),
frame_thread_info AS (
  SELECT
    jf.frame_id,
    jf.upid,
    jf.actual_start,
    jf.actual_end,
    jf.actual_dur,
    jf.jank_type,
    jf.jank_severity_type,
    jf.layer_name,
    jf.session_id,
    jf.token_gap,
    jf.vsync_missed,
    jf.jank_responsibility,
    jf.present_interval_ms,
    jf.is_hidden_jank,
    -- Guilty frame 信息
    gf.guilty_frame_id,
    gf.guilty_dur,
    gf.over_budget_ms,
    -- 生产线程时间范围（动态检测，不依赖硬编码线程名）
    (SELECT MIN(s.ts) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     WHERE t.upid = jf.upid
       AND t.name NOT LIKE 'Binder:%'
       AND s.ts >= jf.actual_start - 5000000
       AND s.ts <= jf.actual_end
       AND (s.name LIKE 'Choreographer#doFrame%' OR s.name LIKE 'Framework::BeginFrame%'
            OR s.name LIKE 'DrawFrame%' OR s.name LIKE 'PlayerLoop%'
            OR s.dur > 2000000)
    ) as main_start_ts,
    (SELECT MAX(s.ts + s.dur) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     WHERE t.upid = jf.upid
       AND t.name NOT LIKE 'Binder:%'
       AND s.ts >= jf.actual_start - 5000000
       AND s.ts <= jf.actual_end
    ) as main_end_ts,
    (SELECT MIN(s.ts) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     JOIN process p ON t.upid = p.upid
     WHERE t.upid = jf.upid
       AND t.tid != p.pid
       AND t.name NOT LIKE 'Binder:%'
       AND s.ts >= jf.actual_start
       AND s.ts <= jf.actual_end
       AND s.dur > 1000000
    ) as render_start_ts,
    (SELECT MAX(s.ts + s.dur) FROM slice s
     JOIN thread_track tt ON s.track_id = tt.id
     JOIN thread t ON tt.utid = t.utid
     JOIN process p ON t.upid = p.upid
     WHERE t.upid = jf.upid
       AND t.tid != p.pid
       AND t.name NOT LIKE 'Binder:%'
       AND s.ts >= jf.actual_start
       AND s.ts <= jf.actual_end
    ) as render_end_ts
  FROM jank_frames jf
  LEFT JOIN guilty_frames gf ON gf.starvation_frame_id = jf.frame_id
)
,
ranked_frames AS (
  SELECT
    fti.frame_id,
    fti.actual_start,
    fti.actual_end,
    fti.main_start_ts,
    fti.main_end_ts,
    fti.render_start_ts,
    fti.render_end_ts,
    fti.actual_dur,
    fti.jank_type,
    fti.jank_severity_type,
    fti.layer_name,
    fti.session_id,
    fti.token_gap,
    fti.vsync_missed,
    fti.jank_responsibility,
    fti.present_interval_ms,
    p.name as process_name,
    p.pid,
    p.upid,
    fti.is_hidden_jank,
    -- Guilty frame 信息
    fti.guilty_frame_id,
    fti.guilty_dur,
    fti.over_budget_ms,
    -- 前序帧信息（用于掉帧原因诊断）
    LAG(fti.actual_dur) OVER (PARTITION BY fti.session_id ORDER BY fti.actual_start) as prev_frame_dur,
    LAG(fti.jank_type) OVER (PARTITION BY fti.session_id ORDER BY fti.actual_start) as prev_frame_jank_type,
    -- 按 vsync_missed 排序（最严重的掉帧优先）
    ROW_NUMBER() OVER (PARTITION BY fti.session_id ORDER BY fti.vsync_missed DESC, fti.actual_dur DESC) as rank_in_session
  FROM frame_thread_info fti
  JOIN process p ON fti.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
)
SELECT
  printf('%d', frame_id) as frame_id,
  printf('%d', actual_start) as start_ts,
  printf('%d', actual_end) as end_ts,
  printf('%d', COALESCE(main_start_ts, actual_start)) as main_start_ts,
  printf('%d', COALESCE(main_end_ts, actual_end)) as main_end_ts,
  COALESCE(main_end_ts - main_start_ts, 0) as main_dur,
  ROUND(COALESCE(main_end_ts - main_start_ts, 0) / 1e6, 2) as main_dur_ms,
  printf('%d', COALESCE(render_start_ts, actual_start)) as render_start_ts,
  printf('%d', COALESCE(render_end_ts, actual_end)) as render_end_ts,
  COALESCE(render_end_ts - render_start_ts, 0) as render_dur,
  ROUND(COALESCE(render_end_ts - render_start_ts, 0) / 1e6, 2) as render_dur_ms,
  printf('%d', actual_dur) as dur,
  ROUND(actual_dur / 1e6, 2) as dur_ms,
  jank_type,
  jank_severity_type,
  layer_name,
  process_name,
  pid,
  session_id,
  token_gap,
  vsync_missed,
  present_interval_ms,
  jank_responsibility,
  -- Guilty frame 信息
  CASE WHEN guilty_frame_id IS NOT NULL THEN printf('%d', guilty_frame_id) END as guilty_frame_id,
  CASE WHEN guilty_dur IS NOT NULL THEN ROUND(guilty_dur / 1e6, 2) END as guilty_dur_ms,
  over_budget_ms,
  -- 掉帧原因说明
  CASE
    -- 管线耗尽：guilty frame 导致缓冲区枯竭
    WHEN guilty_frame_id IS NOT NULL THEN
      '管线耗尽 — 帧 ' || guilty_frame_id || ' 耗时 '
      || ROUND(guilty_dur / 1e6, 2) || 'ms（超出预算 '
      || over_budget_ms || 'ms），导致后续 ' || vsync_missed || ' 帧缓冲区枯竭'
    -- 隐形掉帧：框架标记 None 但 token gap 检测到掉帧
    WHEN jank_responsibility = 'HIDDEN' THEN
      '缓冲区枯竭 — 框架未标记（Perfetto 时间线帧颜色为绿色），'
      || '但该 Layer 跳过 ' || vsync_missed || ' 个 DisplayFrame 无新 buffer'
    -- App Self Jank
    WHEN jank_type = 'Self Jank' THEN
      'App 自身处理超时（' || ROUND(actual_dur / 1e6, 2) || 'ms），跳过 ' || vsync_missed || ' 帧'
    -- App Deadline Missed
    WHEN jank_type = 'App Deadline Missed' THEN
      'App 未在 VSync deadline 前完成渲染（' || ROUND(actual_dur / 1e6, 2) || 'ms），跳过 ' || vsync_missed || ' 帧'
    -- SurfaceFlinger 问题
    WHEN jank_responsibility = 'SF' THEN
      'SurfaceFlinger 合成延迟（' || jank_type || '），App 已按时交付 buffer'
    -- Buffer Stuffing
    WHEN jank_responsibility = 'BUFFER_STUFFING' THEN
      '帧耗时 ' || ROUND(actual_dur / 1e6, 2) || 'ms，BufferQueue 阻塞（Buffer Stuffing），延迟 ' || vsync_missed || ' 个 VSync'
    -- App side
    WHEN jank_responsibility = 'APP' THEN
      'App 超时（' || ROUND(actual_dur / 1e6, 2) || 'ms），跳过 ' || vsync_missed || ' 帧'
    ELSE
      COALESCE(jank_type, '未知') || '，跳过 ' || vsync_missed || ' 帧'
  END as jank_cause,
  is_hidden_jank,
  ROW_NUMBER() OVER (ORDER BY session_id, actual_start) as frame_index
FROM ranked_frames
WHERE rank_in_session <= CASE
  WHEN ${max_frames_per_session} IS NULL THEN 200
  WHEN CAST(${max_frames_per_session} AS INTEGER) <= 0 THEN 200
  ELSE CAST(${max_frames_per_session} AS INTEGER)
END
ORDER BY session_id, actual_start
