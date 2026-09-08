-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 1f7f88a61952702a668509a62d95c478285ae1e000eed21507c133e4fa55c1aa
-- Source commit: 67a2eec9888ed577e66284c709f4987a617bd286

WITH move_events AS (
  SELECT
    dispatch_ts as ts,
    dispatch_ts - LAG(dispatch_ts) OVER (ORDER BY dispatch_ts) as interval_ns
  FROM android_input_events
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
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
  ROUND(PERCENTILE(interval_ns, 50) / 1e6, 2) as median_interval_ms,
  ROUND(1e9 / PERCENTILE(interval_ns, 50), 0) as sampling_rate_hz,
  (SELECT COUNT(*) FROM move_events) as total_events
FROM filtered
