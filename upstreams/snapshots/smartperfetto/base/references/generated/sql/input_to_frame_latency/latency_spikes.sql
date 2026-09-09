-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 1f7f88a61952702a668509a62d95c478285ae1e000eed21507c133e4fa55c1aa
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

WITH latencies AS (
  SELECT
    dispatch_ts as input_ts,
    end_to_end_latency_dur as latency_ns,
    is_speculative_frame
  FROM android_input_events
  WHERE (('${package}' = '' OR process_name = '${package}' OR process_name GLOB '${package}:*') OR '${package}' = '')
    AND event_action = 'MOVE'
    AND (${start_ts} IS NULL OR dispatch_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts <= ${end_ts})
    AND end_to_end_latency_dur IS NOT NULL
    AND end_to_end_latency_dur > 0
    AND end_to_end_latency_dur < 500000000
),
with_prev AS (
  SELECT
    input_ts,
    latency_ns,
    is_speculative_frame,
    LAG(latency_ns) OVER (ORDER BY input_ts) as prev_latency_ns
  FROM latencies
)
SELECT
  printf('%d', input_ts) as input_ts,
  ROUND(latency_ns / 1e6, 2) as latency_ms,
  ROUND(prev_latency_ns / 1e6, 2) as prev_latency_ms,
  ROUND(CAST(latency_ns AS REAL) / MAX(prev_latency_ns, 1), 1) as spike_ratio,
  is_speculative_frame as is_speculative
FROM with_prev
WHERE prev_latency_ns IS NOT NULL
  AND latency_ns > prev_latency_ns * 2
  AND latency_ns > 30000000
ORDER BY spike_ratio DESC
LIMIT 20
