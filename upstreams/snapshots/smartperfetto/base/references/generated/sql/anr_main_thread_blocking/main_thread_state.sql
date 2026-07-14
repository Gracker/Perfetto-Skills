-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 752e67cdf5dd546d65645a1b6da52ba9ab151e46610423c7390997c6e0d4d7a9
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

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
  SELECT t.utid, t.tid, p.upid
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
      MIN(ts_tbl.ts + ts_tbl.dur, (SELECT w_end FROM analysis_window))
      - MAX(ts_tbl.ts, (SELECT w_start FROM analysis_window))
    ) as total_dur_ns
  FROM thread_state ts_tbl
  CROSS JOIN analysis_window aw
  CROSS JOIN main_thread mt
  WHERE ts_tbl.utid = mt.utid
    AND ts_tbl.ts + ts_tbl.dur > aw.w_start
    AND ts_tbl.ts < aw.w_end
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
  ROUND(sd.total_dur_ns / NULLIF(sd.count, 0) / 1e6, 2) as avg_dur_ms,
  ROUND((SELECT MAX(
      MIN(ts2.ts + ts2.dur, (SELECT w_end FROM analysis_window))
      - MAX(ts2.ts, (SELECT w_start FROM analysis_window))
    ) FROM thread_state ts2
    CROSS JOIN analysis_window aw2
    CROSS JOIN main_thread mt2
    WHERE ts2.utid = mt2.utid
      AND ts2.state = sd.state
      AND ts2.ts + ts2.dur > aw2.w_start
      AND ts2.ts < aw2.w_end
  ) / 1e6, 2) as max_dur_ms
FROM state_dist sd
ORDER BY total_dur_ns DESC
