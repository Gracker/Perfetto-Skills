-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/scrolling_analysis.skill.yaml
-- Source SHA-256: db12ba810a107ad991b5f42de2764e08b2d6f86b5f11d57cfb0c50b62773a126
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH
-- 动态 VSync 周期检测（限定在分析区间内，仅用于 session 切分）
vsync_intervals_for_session AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_config_for_session AS (
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
       FROM vsync_intervals_for_session
       WHERE interval_ns > 5500000 AND interval_ns < 50000000),
      16666667
    ) AS INTEGER) AS raw_ns
  )
),
frame_gaps AS (
  SELECT
    COALESCE(a.display_frame_token, a.surface_frame_token) as display_frame_token,
    a.ts, a.dur, a.upid,
    a.layer_name,
    a.jank_type,
    COALESCE(a.present_type, 'Unknown Present') as present_type,
    p.name as process_name,
    a.ts - LAG(a.ts + a.dur) OVER (PARTITION BY a.upid ORDER BY a.ts) as time_gap_ns,
    a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END as present_ts,
    LAG(a.ts + CASE WHEN a.dur > 0 THEN a.dur ELSE 0 END)
      OVER (PARTITION BY a.layer_name ORDER BY a.ts) as prev_present_ts
  FROM actual_frame_timeline_slice a
  JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND p.name NOT LIKE '/system/%'
    AND (${start_ts} IS NULL OR a.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR a.ts < ${end_ts})
    AND a.dur > 0
    AND COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
),
session_markers AS (
  SELECT *,
    CASE WHEN time_gap_ns IS NULL OR time_gap_ns > (SELECT vsync_period_ns * 6 FROM vsync_config_for_session) THEN 1 ELSE 0 END as new_session
  FROM frame_gaps
),
sessions_raw AS (
  SELECT *,
    SUM(new_session) OVER (PARTITION BY upid ORDER BY ts) as session_id
  FROM session_markers
),
sessions AS (
  SELECT
    session_id,
    process_name,
    MIN(ts) as start_ts,
    MAX(ts + dur) as end_ts,
    COUNT(*) as frame_count
  FROM sessions_raw
  GROUP BY upid, session_id
  HAVING COUNT(*) >= 10
    AND (MAX(ts + dur) - MIN(ts)) > 200000000
),
-- 掉帧检测：双信号混合策略
session_token_gap_jank AS (
  SELECT
    sr.session_id,
    -- 感知掉帧：双信号混合检测
    SUM(CASE
      WHEN sr.present_type IN ('Late Present', 'Dropped Frame')
        AND sr.jank_type != 'Buffer Stuffing' THEN 1
      WHEN sr.jank_type = 'Buffer Stuffing'
        AND sr.prev_present_ts IS NOT NULL
        AND sr.present_ts - sr.prev_present_ts > (SELECT vsync_period_ns FROM vsync_config_for_session) * 1.5
        AND sr.present_ts - sr.prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config_for_session) * 6 THEN 1
      ELSE 0 END) as consumer_jank_count,
    SUM(CASE WHEN sr.present_type IN ('Late Present', 'Dropped Frame')
      AND sr.jank_type IN ('Self Jank', 'App Deadline Missed', 'App Resynced Jitter') THEN 1 ELSE 0 END) as app_jank_count,
    -- Buffer Stuffing 总帧数（管线背压，含正常 BS 和异常 BS）
    SUM(CASE WHEN sr.jank_type = 'Buffer Stuffing' THEN 1 ELSE 0 END) as buffer_stuffing_count,
    MAX(CASE
      WHEN (
        (sr.present_type IN ('Late Present', 'Dropped Frame') AND sr.jank_type != 'Buffer Stuffing')
        OR (sr.jank_type = 'Buffer Stuffing' AND sr.prev_present_ts IS NOT NULL
            AND sr.present_ts - sr.prev_present_ts > (SELECT vsync_period_ns FROM vsync_config_for_session) * 1.5
            AND sr.present_ts - sr.prev_present_ts <= (SELECT vsync_period_ns FROM vsync_config_for_session) * 6)
      ) AND sr.prev_present_ts IS NOT NULL
        AND sr.present_ts - sr.prev_present_ts > (SELECT vsync_period_ns FROM vsync_config_for_session) * 1.5
      THEN MAX(CAST(ROUND((sr.present_ts - sr.prev_present_ts) * 1.0 / (SELECT vsync_period_ns FROM vsync_config_for_session) - 1, 0) AS INTEGER), 0)
      ELSE 0 END) as max_vsync_missed,
    GROUP_CONCAT(DISTINCT CASE
      WHEN (sr.present_type IN ('Late Present', 'Dropped Frame') AND sr.jank_type != 'Buffer Stuffing')
        OR (sr.jank_type = 'Buffer Stuffing' AND sr.prev_present_ts IS NOT NULL
            AND sr.present_ts - sr.prev_present_ts > (SELECT vsync_period_ns FROM vsync_config_for_session) * 1.5)
      THEN COALESCE(sr.jank_type, 'None') END) as jank_types
  FROM sessions_raw sr
  GROUP BY sr.session_id
)
SELECT
  s.session_id,
  s.frame_count,
  -- 感知掉帧 = consumer_jank_count（双信号已过滤正常 BS）
  COALESCE(stj.consumer_jank_count, 0) as janky_count,
  ROUND(100.0 * COALESCE(stj.consumer_jank_count, 0) / NULLIF(s.frame_count, 0), 2) as jank_rate,
  COALESCE(stj.app_jank_count, 0) as app_janky_count,
  COALESCE(stj.buffer_stuffing_count, 0) as buffer_stuffing_count,
  COALESCE(stj.max_vsync_missed, 0) as max_vsync_missed,
  stj.jank_types
FROM sessions s
LEFT JOIN session_token_gap_jank stj ON s.session_id = stj.session_id
ORDER BY s.session_id
