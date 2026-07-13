-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_storm_detection.skill.yaml
-- Source SHA-256: 85ad602601d09ed445ea984992373707cec45dc7255c375b7e7af6b610abe463
-- Source commit: a0c1029d26be661802c6ac4b6ae26ded35c8db31

WITH process_stats AS (
  SELECT
    bt.client_process as process_name,
    COUNT(*) as total_txns,
    SUM(CASE WHEN bt.is_sync = 1 THEN 1 ELSE 0 END) as sync_txns,
    SUM(CASE WHEN bt.is_sync = 0 THEN 1 ELSE 0 END) as async_txns,
    ROUND(SUM(bt.client_dur) / 1e6, 2) as total_client_ms,
    ROUND(MAX(bt.client_dur) / 1e6, 2) as max_dur_ms
  FROM android_binder_txns bt
  WHERE (bt.client_process GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR bt.client_ts <= ${end_ts})
  GROUP BY bt.client_process
),
concurrent_estimate AS (
  SELECT
    bt1.client_process as process_name,
    MAX(overlap_count) as concurrent_peak
  FROM (
    SELECT
      bt1.client_process,
      bt1.client_ts,
      COUNT(*) as overlap_count
    FROM android_binder_txns bt1
    JOIN android_binder_txns bt2 ON (
      bt1.client_process = bt2.client_process
      AND bt2.client_ts < bt1.client_ts + bt1.client_dur
      AND bt2.client_ts + bt2.client_dur > bt1.client_ts
    )
    WHERE (bt1.client_process GLOB '${package}*' OR '${package}' = '')
      AND (${start_ts} IS NULL OR bt1.client_ts >= ${start_ts})
      AND (${end_ts} IS NULL OR bt1.client_ts <= ${end_ts})
    GROUP BY bt1.client_process, bt1.client_ts
  ) bt1
  GROUP BY bt1.client_process
)
SELECT
  ps.process_name,
  ps.total_txns,
  ps.sync_txns,
  ps.async_txns,
  ps.total_client_ms,
  COALESCE(ce.concurrent_peak, 1) as concurrent_peak,
  CASE
    WHEN COALESCE(ce.concurrent_peak, 1) > 15 OR ps.total_txns > 1000 THEN '严重'
    WHEN COALESCE(ce.concurrent_peak, 1) > 8 OR ps.total_txns > 500 THEN '需优化'
    WHEN COALESCE(ce.concurrent_peak, 1) > 4 OR ps.total_txns > 200 THEN '正常'
    ELSE '低'
  END as pressure_rating
FROM process_stats ps
LEFT JOIN concurrent_estimate ce ON ce.process_name = ps.process_name
ORDER BY ps.total_txns DESC
LIMIT 20
