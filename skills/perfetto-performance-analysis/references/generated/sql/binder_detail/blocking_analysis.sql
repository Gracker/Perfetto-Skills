-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: b21af48bb190aa382256c422c77267cce8f041f42257cbbd3a6f669e691f5bf9
-- Source commit: fb2c84db1786a214c2a68a89e8143b9b88cb2e00

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND t.tid = p.pid
)
SELECT
  ts.state,
  CASE ts.state
    WHEN 'Running' THEN 'Running (CPU执行)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'S' THEN 'Sleeping (等待Binder回复)'
    WHEN 'D' THEN 'Uninterruptible Sleep (不可中断睡眠; IO需io_wait/blocked_function)'
    ELSE ts.state
  END as state_desc,
  ts.blocked_function,
  ROUND(SUM(
    MIN(ts.ts + ts.dur, ${binder_end_ts}) - MAX(ts.ts, ${binder_ts})
  ) / 1e6, 2) as dur_ms,
  COUNT(*) as count
FROM thread_state ts
JOIN main_thread mt ON ts.utid = mt.utid
WHERE ts.ts < ${binder_end_ts}
  AND ts.ts + ts.dur > ${binder_ts}
GROUP BY ts.state, ts.blocked_function
ORDER BY dur_ms DESC
LIMIT 5
