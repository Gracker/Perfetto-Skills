-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 752e67cdf5dd546d65645a1b6da52ba9ab151e46610423c7390997c6e0d4d7a9
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

-- stdlib android_monitor_contention 提供 blocking_method + blocking_thread
-- futex 部分保留手动 GLOB（stdlib 不覆盖）
WITH analysis_window AS (
  SELECT
    COALESCE(${start_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} - 5000000000 ELSE NULL END,
      (SELECT MIN(ts) FROM slice)
    ) as w_start,
    COALESCE(${end_ts},
      CASE WHEN ${anr_ts} IS NOT NULL THEN ${anr_ts} + 1000000000 ELSE NULL END,
      (SELECT MAX(ts + dur) FROM slice)
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
-- monitor contention: 使用 stdlib 获得 blocking_method 和 owner 信息
monitor_locks AS (
  SELECT
    mc.ts,
    'monitor' as lock_type,
    mc.blocking_method || ' (owner: ' || mc.blocking_thread_name || ')' as slice_name,
    mc.dur,
    mc.blocked_thread_name as thread_name
  FROM android_monitor_contention mc
  CROSS JOIN analysis_window aw
  WHERE mc.blocked_utid = (SELECT utid FROM main_thread)
    AND mc.ts >= aw.w_start
    AND mc.ts + mc.dur <= aw.w_end
),
-- futex: stdlib 不覆盖，保留手动 GLOB
futex_locks AS (
  SELECT
    s.ts,
    'futex' as lock_type,
    s.name as slice_name,
    s.dur,
    t.name as thread_name
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  CROSS JOIN analysis_window aw
  CROSS JOIN main_thread mt
  WHERE tt.utid = mt.utid
    AND s.name GLOB '*futex*'
    AND s.ts >= aw.w_start
    AND s.ts + s.dur <= aw.w_end
)
SELECT
  printf('%d', ts) as ts,
  lock_type,
  slice_name,
  ROUND(dur / 1e6, 2) as dur_ms,
  thread_name
FROM (
  SELECT * FROM monitor_locks
  UNION ALL
  SELECT * FROM futex_locks
)
ORDER BY dur DESC
LIMIT 20
