-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/anr_detail.skill.yaml
-- Source SHA-256: e48c73408b2775bed099612d32832cde9f70ca33cd1cc462e0275b1454588359
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (
      (${upid} > 0 AND p.upid = ${upid})
      OR (${upid} <= 0 AND ${pid} > 0 AND p.pid = ${pid}
          AND ('${process_name}' = '' OR p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
      OR (${upid} <= 0 AND ${pid} <= 0
          AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*'))
    )
    AND t.tid = p.pid
  LIMIT 1
),
anr_window AS (
  SELECT
    ${anr_ts} - ${timeout_ns} as start_ts,
    ${anr_ts} as end_ts
)
SELECT
  COALESCE(waker_thread.name, 'unknown') AS waker_thread,
  COALESCE(waker_process.name, 'kernel') AS waker_process,
  ts.blocked_function,
  COUNT(*) AS wakeup_count,
  ROUND(AVG(ts.dur) / 1e6, 2) AS avg_sleep_ms,
  ROUND(MAX(ts.dur) / 1e6, 2) AS max_sleep_ms,
  ROUND(SUM(ts.dur) / 1e6, 2) AS total_sleep_ms
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
CROSS JOIN anr_window aw
LEFT JOIN thread waker_thread ON ts.waker_utid = waker_thread.utid
LEFT JOIN process waker_process ON waker_thread.upid = waker_process.upid
WHERE ts.ts >= aw.start_ts
  AND ts.ts < aw.end_ts
  AND ts.state IN ('S', 'D', 'I')
  AND ts.dur >= 1000000  -- > 1ms
GROUP BY waker_thread.name, waker_process.name, ts.blocked_function
ORDER BY total_sleep_ms DESC
LIMIT 10
