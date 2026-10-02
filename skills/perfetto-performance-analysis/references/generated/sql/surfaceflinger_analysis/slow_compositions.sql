-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/surfaceflinger_analysis.skill.yaml
-- Source SHA-256: 4d6e1ad9bf86293bfb2b3488cd30b3ff6d382e7560b18a6923e32b2150de4e27

SELECT
  printf('%d', s.ts) as start_ts,
  s.dur,
  s.name as event_name,
  CAST(ROUND(s.dur * 1.0 / ${vsync_env.data[0].vsync_period_ns|NULL} - 1) AS INTEGER) as vsync_missed,
  CASE
    WHEN s.dur > ${vsync_env.data[0].vsync_period_ns|NULL} * 3.0 THEN 'critical'
    WHEN s.dur > ${vsync_env.data[0].vsync_period_ns|NULL} * 2.0 THEN 'warning'
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
  AND s.dur > ${vsync_env.data[0].vsync_period_ns|NULL} * ${slow_composition_multiplier|1.5}
  AND (${start_ts} IS NULL OR s.ts >= ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
ORDER BY s.dur DESC
LIMIT 30
