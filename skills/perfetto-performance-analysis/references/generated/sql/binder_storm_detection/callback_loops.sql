-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_storm_detection.skill.yaml
-- Source SHA-256: 85ad602601d09ed445ea984992373707cec45dc7255c375b7e7af6b610abe463
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

WITH pair_stats AS (
  SELECT
    bt.client_process,
    bt.server_process,
    COUNT(*) as call_count,
    SUM(bt.client_dur) as total_dur
  FROM android_binder_txns bt
  WHERE (bt.client_process GLOB '${package}*' OR bt.server_process GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR bt.client_ts <= ${end_ts})
  GROUP BY bt.client_process, bt.server_process
)
SELECT
  a.client_process as process_a,
  a.server_process as process_b,
  a.call_count as a_to_b_count,
  b.call_count as b_to_a_count,
  ROUND((a.total_dur + b.total_dur) / 1e6, 2) as total_loop_dur_ms,
  ROUND(CAST(MIN(a.call_count, b.call_count) AS REAL) / MAX(a.call_count, b.call_count), 2) as loop_ratio
FROM pair_stats a
JOIN pair_stats b ON a.client_process = b.server_process AND a.server_process = b.client_process
WHERE a.client_process < a.server_process
  AND a.call_count > 3 AND b.call_count > 3
ORDER BY (a.total_dur + b.total_dur) DESC
LIMIT 20
