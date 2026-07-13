-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wakelock_tracking.skill.yaml
-- Source SHA-256: 0384f134ae9d3dff888d962e31723669769e7f31268205c764b027d8888a973c
-- Source commit: 68b113e0355716255af357e8396cd71c71e11d97

SELECT
  printf('%d', s.ts) as ts,
  s.name as wakelock_name,
  p.name as process_name,
  t.name as thread_name,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  printf('%d', s.dur) as dur_ns,
  CASE
    WHEN s.dur / 1e6 > 60000 THEN '长时间持有'
    WHEN s.dur / 1e6 > 10000 THEN '较长持有'
    WHEN s.dur / 1e6 > 1000 THEN '正常'
    ELSE '短暂'
  END as status
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB '*WakeLock*' OR s.name GLOB '*wakelock*'
       OR s.name GLOB '*PowerManager*WakeLock*'
       OR s.name GLOB '*wake_lock*')
ORDER BY s.ts ASC
LIMIT 100
