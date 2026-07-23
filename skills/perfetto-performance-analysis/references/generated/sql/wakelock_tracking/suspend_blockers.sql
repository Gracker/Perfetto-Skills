-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wakelock_tracking.skill.yaml
-- Source SHA-256: 0384f134ae9d3dff888d962e31723669769e7f31268205c764b027d8888a973c
-- Source commit: ff5d4a00696318f7bfc5868fb54c84b38c32b880

SELECT
  s.name as blocker_name,
  t.name as thread_name,
  COUNT(*) as count,
  ROUND(SUM(s.dur) / 1e6, 2) as total_dur_ms,
  ROUND(AVG(s.dur) / 1e6, 2) as avg_dur_ms,
  ROUND(MAX(s.dur) / 1e6, 2) as max_dur_ms
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
  AND (s.name GLOB '*suspend_blocker*' OR s.name GLOB '*SuspendBlocker*'
       OR s.name GLOB '*wakeup_source*' OR s.name GLOB '*WakeupSource*')
GROUP BY s.name, t.name
ORDER BY SUM(s.dur) DESC
LIMIT 30
