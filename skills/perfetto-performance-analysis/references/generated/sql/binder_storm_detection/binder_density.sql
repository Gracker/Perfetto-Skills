-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/binder_storm_detection.skill.yaml
-- Source SHA-256: 85ad602601d09ed445ea984992373707cec45dc7255c375b7e7af6b610abe463
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH binder_txns AS (
  SELECT
    bt.client_ts,
    bt.client_dur,
    bt.client_process as process_name
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
)
SELECT
  printf('%d', w.window_start) as window_ts,
  bt.process_name,
  COUNT(*) as txn_count,
  ROUND(SUM(bt.client_dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(bt.client_dur) / 1e6, 2) as avg_dur_ms,
  CASE
    WHEN COUNT(*) > ${threshold|50} * 2 THEN '严重风暴'
    WHEN COUNT(*) > ${threshold|50} THEN '风暴'
    WHEN COUNT(*) > ${threshold|50} / 2 THEN '密集'
    ELSE '正常'
  END as status
FROM windows w
JOIN binder_txns bt ON bt.client_ts >= w.window_start AND bt.client_ts < w.window_end
GROUP BY w.window_start, bt.process_name
HAVING txn_count > 5
ORDER BY txn_count DESC
LIMIT 50
