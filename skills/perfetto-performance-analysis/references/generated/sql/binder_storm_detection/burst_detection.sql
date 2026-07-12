-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_storm_detection.skill.yaml
-- Source SHA-256: 85ad602601d09ed445ea984992373707cec45dc7255c375b7e7af6b610abe463
-- Source commit: 4489476e5b45a868fbf4bdbf0f10e466870f59bf

WITH binder_txns AS (
  SELECT
    bt.client_ts,
    bt.client_dur,
    bt.client_process as process_name,
    bt.server_process
  FROM android_binder_txns bt
  WHERE (bt.client_process GLOB '${package}*' OR '${package}' = '')
    AND (${start_ts} IS NULL OR bt.client_ts >= ${start_ts})
    AND (${end_ts} IS NULL OR bt.client_ts <= ${end_ts})
),
txn_bounds AS (
  SELECT
    COALESCE(${start_ts}, MIN(client_ts)) as t_start,
    COALESCE(${end_ts}, MAX(client_ts + client_dur)) as t_end
  FROM binder_txns
),
windows AS (
  SELECT
    t_start + (value * 100000000) as window_start,
    t_start + ((value + 1) * 100000000) as window_end
  FROM txn_bounds
  JOIN (
    WITH RECURSIVE cnt(value) AS (
      SELECT 0
      UNION ALL
      SELECT value + 1 FROM cnt
      WHERE value < 3000
    )
    SELECT value FROM cnt
  )
  WHERE t_start + (value * 100000000) < t_end
),
burst_windows AS (
  SELECT
    w.window_start,
    bt.process_name,
    COUNT(*) as txn_count,
    ROUND(SUM(bt.client_dur) / 1e6, 2) as total_dur_ms
  FROM windows w
  JOIN binder_txns bt ON bt.client_ts >= w.window_start AND bt.client_ts < w.window_end
  GROUP BY w.window_start, bt.process_name
  HAVING txn_count > ${threshold|50}
),
top_servers AS (
  SELECT
    bw.window_start,
    bw.process_name,
    bt.server_process,
    COUNT(*) as srv_count,
    ROW_NUMBER() OVER (PARTITION BY bw.window_start, bw.process_name ORDER BY COUNT(*) DESC) as rn
  FROM burst_windows bw
  JOIN binder_txns bt ON bt.client_ts >= bw.window_start
    AND bt.client_ts < bw.window_start + 100000000
    AND bt.process_name = bw.process_name
  GROUP BY bw.window_start, bw.process_name, bt.server_process
)
SELECT
  printf('%d', bw.window_start) as burst_ts,
  bw.process_name,
  bw.txn_count,
  bw.total_dur_ms,
  ts.server_process as top_server,
  ts.srv_count as top_server_count,
  CASE
    WHEN bw.txn_count > ${threshold|50} * 3 THEN 'critical'
    WHEN bw.txn_count > ${threshold|50} * 2 THEN 'warning'
    ELSE 'notice'
  END as severity
FROM burst_windows bw
LEFT JOIN top_servers ts ON ts.window_start = bw.window_start
  AND ts.process_name = bw.process_name AND ts.rn = 1
ORDER BY bw.txn_count DESC
LIMIT 30
