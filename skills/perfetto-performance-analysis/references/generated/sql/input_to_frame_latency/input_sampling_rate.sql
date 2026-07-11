-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
-- Source commit: 1909a9e3d2d62835111539e687fa08c77a8e13fa

WITH move_events AS (
  SELECT
    dispatch_ts as ts,
    dispatch_ts - LAG(dispatch_ts) OVER (ORDER BY dispatch_ts) as interval_ns
  FROM android_input_events
  WHERE (process_name GLOB '${package}*' OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
),
filtered AS (
  SELECT interval_ns FROM move_events
  WHERE interval_ns IS NOT NULL
    AND interval_ns BETWEEN 1000000 AND 100000000
)
SELECT
  ROUND(PERCENTILE(interval_ns, 0.5) / 1e6, 2) as median_interval_ms,
  ROUND(1e9 / PERCENTILE(interval_ns, 0.5), 0) as sampling_rate_hz,
  (SELECT COUNT(*) FROM move_events) as total_events
FROM filtered
