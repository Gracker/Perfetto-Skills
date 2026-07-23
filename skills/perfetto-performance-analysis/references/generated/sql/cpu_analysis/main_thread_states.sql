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
  ts.state,
  CASE ts.state
    WHEN 'Running' THEN 'Running (CPU执行中)'
    WHEN 'R' THEN 'Runnable (等待调度)'
    WHEN 'R+' THEN 'Runnable+ (抢占等待)'
    WHEN 'S' THEN 'Sleeping (可中断睡眠/等待)'
    WHEN 'D' THEN CASE WHEN COALESCE(ts.io_wait, 0) = 1 THEN 'Uninterruptible sleep (io_wait)' ELSE 'Uninterruptible sleep (不可中断等待)' END
    WHEN 'I' THEN 'Idle (空闲)'
    ELSE ts.state
  END as state_desc,
  SUM(ts.dur) / 1e6 as total_dur_ms,
  ROUND(100.0 * SUM(ts.dur) / (
    SELECT SUM(ts2.dur) FROM thread_state ts2
    WHERE ts2.utid = (SELECT utid FROM main_thread)
      AND (${start_ts} IS NULL OR ts2.ts + ts2.dur > ${start_ts})
      AND (${end_ts} IS NULL OR ts2.ts < ${end_ts})
  ), 1) as percent,
  COUNT(*) as count,
  -- IO 等待详情
  CASE WHEN ts.state IN ('D', 'DK') THEN COALESCE(ts.io_wait, 0) ELSE NULL END as io_wait
FROM thread_state ts
WHERE ts.utid = (SELECT utid FROM main_thread)
  AND (${start_ts} IS NULL OR ts.ts + ts.dur > ${start_ts})
  AND (${end_ts} IS NULL OR ts.ts < ${end_ts})
GROUP BY ts.state, CASE WHEN ts.state IN ('D', 'DK') THEN COALESCE(ts.io_wait, 0) ELSE NULL END
ORDER BY total_dur_ms DESC
