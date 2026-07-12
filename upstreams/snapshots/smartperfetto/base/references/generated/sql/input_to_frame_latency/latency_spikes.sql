-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/input_to_frame_latency.skill.yaml
-- Source SHA-256: 3f8a18a4750d12e34a5556236cf069b5e09eaf1c3c3cf2cc5af513f635809c46
-- Source commit: cda248e2324a554220e15f8ce5ede39f2f53468d

WITH latencies AS (
  SELECT
    dispatch_ts as input_ts,
    end_to_end_latency_dur as latency_ns,
    is_speculative_frame
  FROM android_input_events
  WHERE (process_name GLOB '${package}*' OR '${package}' = '')
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
