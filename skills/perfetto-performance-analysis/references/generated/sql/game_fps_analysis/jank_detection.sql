-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/game_fps_analysis.skill.yaml
-- Source SHA-256: 149fad0ed589259b19b7d70e8969cf12c77fc86255551b55aeea19b9705ed7fe
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH
time_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(ts)) as start_ts,
    COALESCE(${end_ts}, MAX(ts + dur)) as end_ts
  FROM actual_frame_timeline_slice
),
-- 自动检测目标帧间隔
target_config AS (
  SELECT
    CASE
      WHEN ${target_fps} IS NOT NULL THEN 1e9 / ${target_fps}
      ELSE (
        SELECT CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER)
        FROM (
          SELECT a.ts - LAG(a.ts) OVER (ORDER BY a.ts) as interval_ns
          FROM actual_frame_timeline_slice a
          LEFT JOIN process p ON a.upid = p.upid
          WHERE (p.name GLOB '${package}*' OR '${package}' = '')
        )
        WHERE interval_ns > 5000000 AND interval_ns < 100000000
      )
    END as target_interval_ns
),
frame_intervals AS (
  SELECT
    a.ts,
    a.ts - LAG(a.ts) OVER (ORDER BY a.ts) as interval_ns
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE (p.name GLOB '${package}*' OR '${package}' = '')
    AND a.surface_frame_token IS NOT NULL
    AND a.ts >= (SELECT start_ts FROM time_bounds)
    AND a.ts <= (SELECT end_ts FROM time_bounds)
),
jank_stats AS (
  SELECT
    COUNT(*) as total_frames,
    -- 帧间隔超过目标 1.5 倍视为掉帧
    SUM(CASE WHEN interval_ns > (SELECT target_interval_ns FROM target_config) * 1.5 THEN 1 ELSE 0 END) as jank_count,
    -- 帧间隔超过目标 2 倍视为严重掉帧
    SUM(CASE WHEN interval_ns > (SELECT target_interval_ns FROM target_config) * 2 THEN 1 ELSE 0 END) as severe_jank_count,
    -- 帧间隔超过目标 3 倍视为卡顿
    SUM(CASE WHEN interval_ns > (SELECT target_interval_ns FROM target_config) * 3 THEN 1 ELSE 0 END) as freeze_count
  FROM frame_intervals
  WHERE interval_ns IS NOT NULL
    AND interval_ns > 5000000
)
SELECT
  total_frames,
  jank_count,
  severe_jank_count,
  freeze_count,
  ROUND(100.0 * jank_count / NULLIF(total_frames, 0), 2) as jank_rate,
  ROUND(100.0 * severe_jank_count / NULLIF(total_frames, 0), 2) as severe_jank_rate,
  ROUND((SELECT target_interval_ns FROM target_config) / 1e6, 2) as target_interval_ms,
  ROUND(1e9 / (SELECT target_interval_ns FROM target_config), 0) as target_fps,
  CASE
    WHEN 100.0 * jank_count / NULLIF(total_frames, 0) < 1 THEN '优秀'
    WHEN 100.0 * jank_count / NULLIF(total_frames, 0) < 5 THEN '良好'
    WHEN 100.0 * jank_count / NULLIF(total_frames, 0) < 10 THEN '一般'
    ELSE '较差'
  END as quality_rating
FROM jank_stats
