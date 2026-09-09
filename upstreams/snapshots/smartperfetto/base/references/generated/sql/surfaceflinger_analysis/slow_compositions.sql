-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 59c8f596d0111ef62440eb05318e85cfc2368d1d0b62d50ed6b1147b21e58aac
-- Source commit: 2b51bc3d909d2c7a877853ffc644d7a042057f38

SELECT
  printf('%d', s.ts) as start_ts,
  s.dur,
  s.name as event_name,
  CAST(ROUND(s.dur * 1.0 / ${vsync_env.data[0].vsync_period_ns} - 1) AS INTEGER) as vsync_missed,
  CASE
    WHEN s.dur > ${vsync_env.data[0].vsync_period_ns} * 3.0 THEN 'critical'
    WHEN s.dur > ${vsync_env.data[0].vsync_period_ns} * 2.0 THEN 'warning'
    ELSE 'notice'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE (p.name = 'surfaceflinger' OR p.name = '/system/bin/surfaceflinger')
  AND (s.name GLOB '*onMessageInvalidate*'
       OR s.name GLOB '*onMessageRefresh*'
       OR s.name GLOB '*composite*'
       OR s.name GLOB '*Composite*')
  AND s.dur > ${vsync_env.data[0].vsync_period_ns} * ${slow_composition_multiplier|1.5}
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
ORDER BY s.dur DESC
LIMIT 30
