-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 1f7f88a61952702a668509a62d95c478285ae1e000eed21507c133e4fa55c1aa
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
vsync_cfg AS (
  SELECT COALESCE(
    CAST(PERCENTILE(interval_ns, 50) AS INTEGER),
    16666667
  ) as period_ns
  FROM vsync_intervals
  WHERE interval_ns BETWEEN 5500000 AND 50000000
),
valid AS (
  SELECT end_to_end_latency_dur as latency_ns
  FROM android_input_events
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
    AND end_to_end_latency_dur IS NOT NULL
    AND end_to_end_latency_dur > 0
    AND end_to_end_latency_dur < 500000000
)
SELECT 'P50' as metric, ROUND(PERCENTILE(latency_ns, 50) / 1e6, 2) as value_ms FROM valid
UNION ALL
SELECT 'P90', ROUND(PERCENTILE(latency_ns, 90) / 1e6, 2) FROM valid
UNION ALL
SELECT 'P99', ROUND(PERCENTILE(latency_ns, 99) / 1e6, 2) FROM valid
UNION ALL
SELECT '均值', ROUND(AVG(latency_ns) / 1e6, 2) FROM valid
UNION ALL
SELECT '标准差', ROUND(SQRT(AVG(latency_ns * latency_ns) - AVG(latency_ns) * AVG(latency_ns)) / 1e6, 2) FROM valid
UNION ALL
SELECT '样本数', CAST(COUNT(*) AS REAL) FROM valid
UNION ALL
SELECT 'VSync周期(ms)', ROUND((SELECT period_ns FROM vsync_cfg) / 1e6, 2) FROM valid LIMIT 1
