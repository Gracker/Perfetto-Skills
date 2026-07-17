-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: d2c7a63dade5310e92b508c129b78b4e3a420c57d613ac75107d93e89f7418cf
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  LIMIT 1
),
blocked AS (
  SELECT
    ts_tbl.blocked_function,
    ts_tbl.dur
  FROM thread_state ts_tbl
  CROSS JOIN main_thread mt
  WHERE ts_tbl.utid = mt.utid
    AND ts_tbl.state IN ('S', 'D')
    AND ts_tbl.blocked_function IS NOT NULL
    AND ts_tbl.blocked_function != ''
    AND ts_tbl.ts + ts_tbl.dur > ${start_ts}
    AND ts_tbl.ts < ${end_ts}
),
total AS (
  SELECT SUM(dur) as total_ns FROM blocked
)
SELECT
  blocked_function,
  ROUND(SUM(dur) / 1e6, 2) as total_dur_ms,
  COUNT(*) as count,
  ROUND(100.0 * SUM(dur) / NULLIF((SELECT total_ns FROM total), 0), 1) as pct
FROM blocked
GROUP BY blocked_function
ORDER BY SUM(dur) DESC
LIMIT 10
