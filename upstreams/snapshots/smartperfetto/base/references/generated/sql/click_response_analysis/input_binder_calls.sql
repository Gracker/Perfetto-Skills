-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/click_response_analysis.skill.yaml
-- Source SHA-256: 0f803fbe7f82fcbcf288bfe2fb88bab8e0ad54cb2df2995d710a285a31b733c6
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

WITH slow_inputs AS (
  SELECT
    dispatch_ts as input_ts,
    receive_ts + receive_dur as input_end_ts,
    total_latency_dur
  FROM android_input_events
  WHERE process_name = '${target_process.data[0].process_name}'
    AND (${start_ts} IS NULL OR receive_ts + receive_dur > ${start_ts})
    AND (${end_ts} IS NULL OR dispatch_ts < ${end_ts})
    AND total_latency_dur > ${thread_state_min_dur_ms|50} * 1000000
  ORDER BY total_latency_dur DESC
  LIMIT 10
)
SELECT
  bt.server_process,
  bt.aidl_name,
  COUNT(*) as call_count,
  SUM(bt.client_dur) / 1e6 as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  SUM(CASE WHEN bt.is_main_thread THEN 1 ELSE 0 END) as main_thread_calls
FROM android_binder_txns bt
JOIN slow_inputs si ON (
  bt.client_ts >= si.input_ts AND bt.client_ts < si.input_end_ts
)
WHERE bt.client_process = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR bt.client_ts + bt.client_dur > ${start_ts})
  AND (${end_ts} IS NULL OR bt.client_ts < ${end_ts})
GROUP BY bt.server_process, bt.aidl_name
ORDER BY total_dur_ms DESC
LIMIT 15
