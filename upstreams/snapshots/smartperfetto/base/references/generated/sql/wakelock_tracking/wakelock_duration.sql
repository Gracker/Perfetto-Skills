-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/atomic/wakelock_tracking.skill.yaml
-- Source SHA-256: 0384f134ae9d3dff888d962e31723669769e7f31268205c764b027d8888a973c
-- Source commit: 053b09e27d56c7727cbe5d7447e32a50b41c5bee

WITH trace_duration AS (
  SELECT
    COALESCE(${end_ts}, (SELECT MAX(ts + dur) FROM slice)) -
    COALESCE(${start_ts}, (SELECT MIN(ts) FROM slice)) as total_ns
),
wl_stats AS (
  SELECT
    s.name as wakelock_name,
    SUM(s.dur) as total_held_ns,
    COUNT(*) as acquire_count,
    AVG(s.dur) as avg_held_ns
  FROM slice s
  JOIN thread_track tt ON s.track_id = tt.id
  JOIN thread t ON tt.utid = t.utid
  WHERE (${start_ts} IS NULL OR s.ts >= ${start_ts})
    AND (${end_ts} IS NULL OR s.ts + s.dur <= ${end_ts})
    AND (s.name GLOB '*WakeLock*' OR s.name GLOB '*wakelock*'
         OR s.name GLOB '*PowerManager*WakeLock*'
         OR s.name GLOB '*wake_lock*')
  GROUP BY s.name
)
SELECT
  wl.wakelock_name,
  ROUND(wl.total_held_ns / 1e6, 2) as total_held_ms,
  ROUND(100.0 * wl.total_held_ns / td.total_ns, 2) as total_held_pct,
  wl.acquire_count,
  ROUND(wl.avg_held_ns / 1e6, 2) as avg_held_ms
FROM wl_stats wl
CROSS JOIN trace_duration td
ORDER BY wl.total_held_ns DESC
LIMIT 20
