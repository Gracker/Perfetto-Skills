-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/vsync_config.skill.yaml
-- Source SHA-256: 7dbf90d2995e488a38404e815e4b85f2674d51b83d6a59b78ae3ed4bcc08d946
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH
-- 方法1: 从 expected_frame_timeline_slice 获取 vsync 周期（回退来源）
-- 当提供 start_ts/end_ts 时，只看该区间内的帧（避免 VRR 省电时段干扰）
expected_frame_vsync AS (
  SELECT
    CAST(PERCENTILE(dur, 0.5) AS INTEGER) as vsync_period_ns,
    'expected_frame_dur' as source
  FROM expected_frame_timeline_slice
  WHERE dur > 5000000 AND dur < 50000000  -- 5ms-50ms 覆盖 24Hz VRR
    AND (${start_ts} IS NULL OR ts >= ${start_ts})
    AND (${end_ts} IS NULL OR ts < ${end_ts})
),
-- 方法2: 从 VSYNC-sf counter track 推算周期 (优先来源)
-- counter 值在 0/1 间交替，每次变化代表一个 vsync tick
sf_vsync_intervals AS (
  SELECT
    c.ts,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
-- 合并结果，sf_vsync 优先，expected_frame 回退
vsync_median AS (
  SELECT
    CASE
      WHEN raw_period BETWEEN 5500000 AND 6500000 THEN 6060606
      WHEN raw_period BETWEEN 6500001 AND 7500000 THEN 6944444
      WHEN raw_period BETWEEN 7500001 AND 9500000 THEN 8333333
      WHEN raw_period BETWEEN 9500001 AND 12500000 THEN 11111111
      WHEN raw_period BETWEEN 12500001 AND 20000000 THEN 16666667
      WHEN raw_period BETWEEN 20000001 AND 35000000 THEN 33333333
      ELSE raw_period
    END AS vsync_period_ns,
    source
  FROM (
    SELECT
      CAST(COALESCE(
        (SELECT PERCENTILE(interval_ns, 0.5)
         FROM sf_vsync_intervals
         WHERE interval_ns > 5500000 AND interval_ns < 50000000),
        (SELECT vsync_period_ns FROM expected_frame_vsync WHERE vsync_period_ns > 0),
        16666667
      ) AS INTEGER) as raw_period,
      CASE
        WHEN (SELECT COUNT(*) FROM sf_vsync_intervals WHERE interval_ns > 5500000 AND interval_ns < 50000000) > 0 THEN 'sf_vsync_counter'
        WHEN (SELECT vsync_period_ns FROM expected_frame_vsync WHERE vsync_period_ns > 0) IS NOT NULL THEN 'expected_frame_dur'
        ELSE 'default_60hz'
      END as source
  )
)
SELECT
  vsync_period_ns,
  refresh_rate_hz,
  ROUND(vsync_period_ns / 1e6, 2) as vsync_period_ms,
  source as vsync_source,
  refresh_rate_hz as detected_refresh_rate
FROM (
  SELECT
    vsync_period_ns,
    CAST(ROUND(1e9 / vsync_period_ns) AS INTEGER) as refresh_rate_hz,
    source
  FROM vsync_median
)
