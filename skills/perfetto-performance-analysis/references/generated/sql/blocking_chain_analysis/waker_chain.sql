-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: d2c7a63dade5310e92b508c129b78b4e3a420c57d613ac75107d93e89f7418cf
-- Source commit: 6333623a96295c1ad76e28bf1f5eb7a9ecd39864

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  LIMIT 1
),
wakeups AS (
  SELECT
    ts_tbl.ts + ts_tbl.dur as wakeup_ts,
    ts_tbl.dur as sleep_dur,
    ts_tbl.blocked_function,
    wt.name as waker_thread_name,
    wp.name as waker_process_name
  FROM thread_state ts_tbl
  CROSS JOIN main_thread mt
  LEFT JOIN thread wt ON ts_tbl.waker_utid = wt.utid
  LEFT JOIN process wp ON wt.upid = wp.upid
  WHERE ts_tbl.utid = mt.utid
    AND ts_tbl.state IN ('S', 'D')
    AND ts_tbl.waker_utid IS NOT NULL
    AND ts_tbl.ts + ts_tbl.dur > ${start_ts}
    AND ts_tbl.ts < ${end_ts}
)
SELECT
  printf('%d', MIN(wakeup_ts)) as ts,
  waker_thread_name,
  waker_process_name,
  blocked_function,
  ROUND(SUM(sleep_dur) / 1e6, 2) as total_sleep_dur_ms,
  ROUND(MAX(sleep_dur) / 1e6, 2) as max_sleep_dur_ms,
  COUNT(*) as wakeup_count
FROM wakeups
WHERE waker_thread_name IS NOT NULL
GROUP BY waker_thread_name, waker_process_name, blocked_function
ORDER BY SUM(sleep_dur) DESC
LIMIT 15
