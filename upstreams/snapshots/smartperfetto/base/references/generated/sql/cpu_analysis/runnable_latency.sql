-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH main_thread AS (
  SELECT t.utid, t.name
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  ts.dur / 1e6 as wait_ms,
  ts.ts / 1e6 as ts_ms,
  printf('%d', ts.ts) as ts_str,
  ts.dur as dur_ns,
  (SELECT name FROM main_thread) as thread_name,
  -- 关联唤醒者信息
  waker_t.name as waker_thread,
  waker_p.name as waker_process,
  CASE
    WHEN ts.dur / 1e6 > ${sched_delay_critical_ms|16} THEN 'critical'
    WHEN ts.dur / 1e6 > ${sched_delay_critical_ms|16} / 2 THEN 'warning'
    ELSE 'normal'
  END as severity
FROM thread_state ts
LEFT JOIN thread waker_t ON ts.waker_utid = waker_t.utid
LEFT JOIN process waker_p ON waker_t.upid = waker_p.upid
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND ts.state IN ('R', 'R+')
  AND ts.dur > 1000000  -- > 1ms
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
ORDER BY ts.dur DESC
LIMIT 20
