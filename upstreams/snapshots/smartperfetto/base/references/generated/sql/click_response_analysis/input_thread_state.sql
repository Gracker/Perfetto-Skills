-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: a683f7c10493d63ecfafe51652f068c9c9694cba

WITH main_thread AS (
  SELECT t.utid, p.name as process_name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name = '${target_process.data[0].process_name}'
    AND t.tid = p.pid
  LIMIT 1
),
slow_inputs AS (
  SELECT
    dispatch_ts as input_ts,
    receive_ts + receive_dur as input_end_ts,
    total_latency_dur,
    event_type
  FROM android_input_events
  WHERE process_name = '${target_process.data[0].process_name}'
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
    AND total_latency_dur > ${thread_state_min_dur_ms|50} * 1000000  -- > thread state threshold
  ORDER BY total_latency_dur DESC
  LIMIT 10
)
SELECT
  si.event_type,
  si.total_latency_dur / 1e6 as input_dur_ms,
  ts.state,
  SUM(
    CASE
      WHEN ts.ts + ts.dur <= si.input_ts THEN 0
      WHEN ts.ts >= si.input_end_ts THEN 0
      ELSE MIN(ts.ts + ts.dur, si.input_end_ts) - MAX(ts.ts, si.input_ts)
    END
  ) / 1e6 as state_dur_ms,
  ts.blocked_function
FROM slow_inputs si
JOIN thread_state ts ON ts.utid = (SELECT utid FROM main_thread)
WHERE ts.ts + ts.dur > si.input_ts
  AND ts.ts < si.input_end_ts
GROUP BY si.input_ts, ts.state, ts.blocked_function
ORDER BY si.total_latency_dur DESC, state_dur_ms DESC
LIMIT 30
