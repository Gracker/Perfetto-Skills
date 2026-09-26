-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: ec3db5b12031c8cedf7480f0e7496dd03c5a0e7ecad513cc72cd26cf8e68c0a2
-- Source commit: 72ae55e84a6cac2d2c62b14cc31c5d0165232799

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  ORDER BY
    (p.name = '${process_name}') DESC,
    EXISTS(SELECT 1 FROM thread_state ts WHERE ts.utid = t.utid) DESC,
    t.utid
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
