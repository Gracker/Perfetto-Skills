-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/cpu_analysis.skill.yaml
-- Source SHA-256: c2723137b1cdfaa2c0f8b23cc62a9133aa534e56dc981c472ddc8d28ca6dff14
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.upid = ${target_process.data[0].upid} AND t.tid = p.pid
  LIMIT 1
)
SELECT
  waker_t.name as waker_thread,
  waker_p.name as waker_process,
  COUNT(*) as wakeup_count,
  SUM(ts.dur) / 1e6 as total_wait_before_wakeup_ms,
  ROUND(AVG(ts.dur) / 1e6, 2) as avg_wait_ms,
  -- IRQ context
  SUM(CASE WHEN ts.irq_context = 1 THEN 1 ELSE 0 END) as irq_wakeups
FROM thread_state ts
JOIN thread waker_t ON ts.waker_utid = waker_t.utid
JOIN process waker_p ON waker_t.upid = waker_p.upid
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND ts.state IN ('R', 'R+')
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
GROUP BY waker_t.utid
ORDER BY wakeup_count DESC
LIMIT 15
