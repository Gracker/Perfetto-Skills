-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/consumer_jank_detection.skill.yaml
-- Source SHA-256: 55465b17c1e74abda8e2e04bb70d0c079459a9f4095de2b56b420ac9721ee0c0
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH
vsync_ticks AS (
  SELECT
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
vsync_period AS (
  SELECT CAST(COALESCE(
    (SELECT PERCENTILE(interval_ns, 0.5)
     FROM vsync_ticks
     WHERE interval_ns > 5500000 AND interval_ns < 50000000),
    (SELECT CAST(PERCENTILE(dur, 0.5) AS INTEGER)
     FROM expected_frame_timeline_slice
     WHERE dur > 5000000 AND dur < 50000000
       AND (${start_ts} IS NULL OR ts >= ${start_ts})
       AND (${end_ts} IS NULL OR ts < ${end_ts})),
    16666667
  ) AS INTEGER) as vsync_period_ns
),
vsync_events AS (
  SELECT
    c.ts as vsync_ts,
    c.ts - LAG(c.ts) OVER (ORDER BY c.ts) as interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-sf'
    AND (${start_ts} IS NULL OR c.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR c.ts < ${end_ts})
),
buffer_events AS (
  SELECT c.ts, c.value as buffer_count
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name LIKE '%BufferTX%'
    AND (t.name LIKE '%${package}%' OR '${package}' = '')
    AND ('${end_ts}' = '' OR c.ts <= CAST('${end_ts}' AS INTEGER))
),
vsync_with_buffer AS (
  SELECT
    v.vsync_ts,
    v.interval_ns,
    (SELECT b.buffer_count
     FROM buffer_events b
     WHERE b.ts <= v.vsync_ts
     ORDER BY b.ts DESC
     LIMIT 1
    ) as buffer_at_vsync
  FROM vsync_events v
  WHERE v.interval_ns IS NOT NULL
),
jank_events AS (
  SELECT
    vsync_ts,
    interval_ns,
    MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period) - 1, 0) AS INTEGER), 0) as vsync_missed
  FROM vsync_with_buffer
  WHERE buffer_at_vsync IS NOT NULL
    AND interval_ns > (SELECT vsync_period_ns FROM vsync_period) * 1.5
),
vsync_stats AS (
  SELECT
    COUNT(*) as total_frames,
    (SELECT COUNT(*) FROM jank_events) as consumer_jank_frames,
    COALESCE((SELECT MAX(vsync_missed) FROM jank_events), 0) as max_vsync_missed,
    COALESCE((SELECT AVG(vsync_missed + 1.0) FROM (
      SELECT MAX(CAST(ROUND(interval_ns * 1.0 / (SELECT vsync_period_ns FROM vsync_period), 0) AS INTEGER), 1) as vsync_missed
      FROM vsync_with_buffer
      WHERE buffer_at_vsync IS NOT NULL
    )), 1.0) as avg_token_gap
  FROM vsync_with_buffer
  WHERE buffer_at_vsync IS NOT NULL
),
app_stats AS (
  SELECT
    COUNT(*) as app_total_frames,
    SUM(CASE WHEN COALESCE(a.jank_type, 'None') != 'None' THEN 1 ELSE 0 END) as app_reported_jank
  FROM actual_frame_timeline_slice a
  LEFT JOIN process p ON a.upid = p.upid
  WHERE COALESCE(a.display_frame_token, a.surface_frame_token) IS NOT NULL
    AND (
      a.layer_name LIKE 'TX - ${package}%'
      OR a.layer_name = '${layer_name}'
      OR ('${package}' = '' AND '${layer_name}' = '')
    )
    AND ('${start_ts}' = '' OR a.ts >= CAST('${start_ts}' AS INTEGER))
    AND ('${end_ts}' = '' OR a.ts <= CAST('${end_ts}' AS INTEGER))
)
SELECT
  (SELECT total_frames FROM vsync_stats) as vsync_total_frames,
  COALESCE((SELECT app_total_frames FROM app_stats), 0) as app_total_frames,
  (SELECT consumer_jank_frames FROM vsync_stats) as consumer_jank_frames,
  (SELECT total_frames FROM vsync_stats) - (SELECT consumer_jank_frames FROM vsync_stats) as smooth_frames,
  ROUND(100.0 * (SELECT consumer_jank_frames FROM vsync_stats) / NULLIF((SELECT total_frames FROM vsync_stats), 0), 2) as consumer_jank_rate,
  COALESCE((SELECT app_reported_jank FROM app_stats), 0) as old_logic_jank_count,
  ROUND(100.0 * COALESCE((SELECT app_reported_jank FROM app_stats), 0) / NULLIF(COALESCE((SELECT app_total_frames FROM app_stats), 0), 0), 2) as old_logic_jank_rate,
  MAX(COALESCE((SELECT app_reported_jank FROM app_stats), 0) - (SELECT consumer_jank_frames FROM vsync_stats), 0) as false_positives,
  MAX((SELECT consumer_jank_frames FROM vsync_stats) - COALESCE((SELECT app_reported_jank FROM app_stats), 0), 0) as false_negatives,
  (SELECT max_vsync_missed FROM vsync_stats) as max_vsync_missed,
  ROUND((SELECT avg_token_gap FROM vsync_stats), 2) as avg_token_gap,
  CASE
    WHEN 100.0 * (SELECT consumer_jank_frames FROM vsync_stats) / NULLIF((SELECT total_frames FROM vsync_stats), 0) < 1 THEN '优秀'
    WHEN 100.0 * (SELECT consumer_jank_frames FROM vsync_stats) / NULLIF((SELECT total_frames FROM vsync_stats), 0) < 5 THEN '良好'
    WHEN 100.0 * (SELECT consumer_jank_frames FROM vsync_stats) / NULLIF((SELECT total_frames FROM vsync_stats), 0) < 15 THEN '一般'
    ELSE '较差'
  END as rating
LIMIT 1
