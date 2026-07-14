-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wakelock_tracking.skill.yaml
-- Source SHA-256: 0384f134ae9d3dff888d962e31723669769e7f31268205c764b027d8888a973c
-- Source commit: e656c756ddaf23a13c7cffdced2f87f75aa07e49

SELECT
  s.name as wakelock_name,
  p.name as process_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms,
  CASE
    WHEN MAX(s.dur) / 1e6 > 60000 THEN '严重'
    WHEN MAX(s.dur) / 1e6 > 10000 THEN '需优化'
    WHEN SUM(s.dur) / 1e6 > 30000 THEN '需优化'
    ELSE '正常'
  END as rating
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB '*WakeLock*' OR s.name GLOB '*wakelock*'
       OR s.name GLOB '*PowerManager*WakeLock*'
       OR s.name GLOB '*wake_lock*')
GROUP BY s.name, p.name
ORDER BY SUM(s.dur) DESC
