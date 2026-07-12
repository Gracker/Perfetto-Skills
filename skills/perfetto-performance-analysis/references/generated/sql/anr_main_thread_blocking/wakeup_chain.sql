-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 752e67cdf5dd546d65645a1b6da52ba9ab151e46610423c7390997c6e0d4d7a9
-- Source commit: 1e23eb4369431c88f9847dcec69ccb81946bdb26

WITH analysis_window AS (
  SELECT
    COALESCE(${start_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} - 5000000000 ELSE NULL END,
      (SELECT MIN(ts) FROM thread_state)
    ) as w_start,
    COALESCE(${end_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} + 1000000000 ELSE NULL END,
      (SELECT MAX(ts + dur) FROM thread_state)
    ) as w_end
),
main_thread AS (
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
    ts_tbl.waker_utid,
    wt.name as waker_thread_name,
    wp.name as waker_process_name
  FROM thread_state ts_tbl
  CROSS JOIN analysis_window aw
  CROSS JOIN main_thread mt
  LEFT JOIN thread wt ON ts_tbl.waker_utid = wt.utid
  LEFT JOIN process wp ON wt.upid = wp.upid
  WHERE ts_tbl.utid = mt.utid
    AND ts_tbl.state IN ('S', 'D')
    AND ts_tbl.waker_utid IS NOT NULL
    AND ts_tbl.ts + ts_tbl.dur > aw.w_start
    AND ts_tbl.ts < aw.w_end
)
SELECT
  printf('%d', MIN(wakeup_ts)) as ts,
  waker_thread_name,
  waker_process_name,
  ROUND(MAX(sleep_dur) / 1e6, 2) as sleep_dur_ms,
  blocked_function,
  COUNT(*) as wakeup_count
FROM wakeups
WHERE waker_thread_name IS NOT NULL
GROUP BY waker_thread_name, waker_process_name, blocked_function
ORDER BY MAX(sleep_dur) DESC
LIMIT 20
