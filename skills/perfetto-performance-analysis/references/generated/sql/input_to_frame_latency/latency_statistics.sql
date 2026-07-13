-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH vsync_intervals AS (
  SELECT c.ts - LAG(c.ts) OVER (ORDER BY c.ts) AS interval_ns
  FROM counter c
  JOIN counter_track t ON c.track_id = t.id
  WHERE t.name = 'VSYNC-app'
),
vsync_cfg AS (
  SELECT COALESCE(
    CAST(PERCENTILE(interval_ns, 0.5) AS INTEGER),
    16666667
  ) as period_ns
  FROM vsync_intervals
  WHERE interval_ns BETWEEN 5500000 AND 50000000
),
valid AS (
  SELECT end_to_end_latency_dur as latency_ns
  FROM android_input_events
  WHERE (process_name GLOB '${package}*' OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
    AND end_to_end_latency_dur IS NOT NULL
    AND end_to_end_latency_dur > 0
    AND end_to_end_latency_dur < 500000000
)
SELECT 'P50' as metric, ROUND(PERCENTILE(latency_ns, 0.5) / 1e6, 2) as value_ms FROM valid
UNION ALL
SELECT 'P90', ROUND(PERCENTILE(latency_ns, 0.9) / 1e6, 2) FROM valid
UNION ALL
SELECT 'P99', ROUND(PERCENTILE(latency_ns, 0.99) / 1e6, 2) FROM valid
UNION ALL
SELECT '均值', ROUND(AVG(latency_ns) / 1e6, 2) FROM valid
UNION ALL
SELECT '标准差', ROUND(SQRT(AVG(latency_ns * latency_ns) - AVG(latency_ns) * AVG(latency_ns)) / 1e6, 2) FROM valid
UNION ALL
SELECT '样本数', CAST(COUNT(*) AS REAL) FROM valid
UNION ALL
SELECT 'VSync周期(ms)', ROUND((SELECT period_ns FROM vsync_cfg) / 1e6, 2) FROM valid LIMIT 1
