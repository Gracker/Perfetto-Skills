-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/anr_main_thread_blocking.skill.yaml
-- Source SHA-256: 125f6c0f585e4fb4e02d376ddf8c103f5229e42fbdff3be9b176133960f18834

-- stdlib android_monitor_contention 提供 blocking_method + blocking_thread
-- futex 部分保留手动 GLOB（stdlib 不覆盖）
WITH main_thread AS (
  SELECT t.utid
  FROM thread t
  JOIN process p ON t.upid = p.upid
  WHERE '${process_name}' != '' AND (p.name = '${process_name}' OR p.name GLOB '${process_name}:*')
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
  WHERE mc.blocked_utid = (SELECT utid FROM main_thread)
    AND mc.ts >= ${analysis_window.data[0].start_ts|NULL}
    AND mc.ts + mc.dur <= ${analysis_window.data[0].end_ts|NULL}
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
  CROSS JOIN main_thread mt
  WHERE tt.utid = mt.utid
    AND s.name GLOB '*futex*'
    AND s.ts >= ${analysis_window.data[0].start_ts|NULL}
    AND s.ts + s.dur <= ${analysis_window.data[0].end_ts|NULL}
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
