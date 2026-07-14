-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/blocking_chain_analysis.skill.yaml
-- Source SHA-256: d2c7a63dade5310e92b508c129b78b4e3a420c57d613ac75107d93e89f7418cf
-- Source commit: a5cefea76e5dfa550683414ffe23ec3a65a46bfb

WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE p.name GLOB '${process_name}*'
    AND (t.is_main_thread = 1 OR t.tid = p.pid)
  LIMIT 1
),
state_dist AS (
  SELECT
    ts_tbl.state,
    COUNT(*) as count,
    SUM(
      MIN(ts_tbl.ts + ts_tbl.dur, ${end_ts})
      - MAX(ts_tbl.ts, ${start_ts})
    ) as total_dur_ns,
    -- 找到该状态下最常见的 blocked_function
    (SELECT bf.blocked_function
     FROM thread_state bf
     CROSS JOIN main_thread mt2
     WHERE bf.utid = mt2.utid
       AND bf.state = ts_tbl.state
       AND bf.blocked_function IS NOT NULL
       AND bf.blocked_function != ''
       AND bf.ts + bf.dur > ${start_ts}
       AND bf.ts < ${end_ts}
     GROUP BY bf.blocked_function
     ORDER BY SUM(bf.dur) DESC
     LIMIT 1
    ) as top_blocked_function
  FROM thread_state ts_tbl
  CROSS JOIN main_thread mt
  WHERE ts_tbl.utid = mt.utid
    AND ts_tbl.ts + ts_tbl.dur > ${start_ts}
    AND ts_tbl.ts < ${end_ts}
  GROUP BY ts_tbl.state
),
total AS (
  SELECT SUM(total_dur_ns) as total_ns FROM state_dist
)
SELECT
  sd.state,
  CASE sd.state
    WHEN 'Running' THEN 'Running (运行中)'
    WHEN 'R' THEN 'Runnable (可运行)'
    WHEN 'R+' THEN 'Runnable (Preempted)'
    WHEN 'S' THEN 'Sleeping (睡眠/等待)'
    WHEN 'D' THEN 'Uninterruptible Sleep (不可中断睡眠)'
    WHEN 'T' THEN 'Stopped (已停止)'
    WHEN 'X' THEN 'Dead (已退出)'
    ELSE sd.state
  END as state_display,
  ROUND(sd.total_dur_ns / 1e6, 2) as total_dur_ms,
  sd.count,
  ROUND(100.0 * sd.total_dur_ns / NULLIF((SELECT total_ns FROM total), 0), 1) as pct,
  sd.top_blocked_function as blocked_function
FROM state_dist sd
ORDER BY total_dur_ns DESC
