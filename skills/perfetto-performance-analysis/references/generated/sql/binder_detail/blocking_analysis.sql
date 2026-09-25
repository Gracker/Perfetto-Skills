-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/binder_detail.skill.yaml
-- Source SHA-256: abd94ce08b891e6024eee4eb3ed9edc80baf296988105e6eebafe7e693921759
-- Source commit: d00e17d1ea0f0fe6fea8fe9981d173169cc6c9c5

WITH main_thread AS (
  SELECT t.utid, t.tid, p.pid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
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
