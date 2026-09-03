-- GENERATED FILE - DO NOT EDIT.
-- Source: backend/skills/composite/navigation_analysis.skill.yaml
-- Source SHA-256: b9e2d3fb86601d2c0f82d87e454f701201afac230ce76013877fe2252698fdb9
-- Source commit: 5ef82a7c8d215414a569c1f857d6a693fa51612f

SELECT
  printf('%d', s.ts) as event_ts,
  printf('%d', s.dur) as dur_ns,
  s.name as event_name,
  CASE
    WHEN s.name GLOB '*performCreate*' OR s.name GLOB '*activityStart*' THEN 'onCreate'
    WHEN s.name GLOB '*performStart*' THEN 'onStart'
    WHEN s.name GLOB '*performResume*' OR s.name GLOB '*activityResume*' THEN 'onResume'
    WHEN s.name GLOB '*performPause*' THEN 'onPause'
    WHEN s.name GLOB '*performStop*' THEN 'onStop'
    WHEN s.name GLOB '*performDestroy*' THEN 'onDestroy'
    ELSE 'other'
  END as phase,
  ROUND(s.dur / 1e6, 2) as dur_ms,
  CASE
    WHEN s.dur / 1e6 > ${oncreate_slow_ms|200} THEN 'critical'
    WHEN s.dur / 1e6 > ${slow_lifecycle_ms|100} THEN 'warning'
    WHEN s.dur / 1e6 > 50 THEN 'notice'
    ELSE 'normal'
  END as severity
FROM slice s
JOIN thread_track tt ON s.track_id = tt.id
JOIN thread t ON tt.utid = t.utid
JOIN process p ON t.upid = p.upid
WHERE t.tid = p.pid
  AND p.name = '${target_process.data[0].process_name}'
  AND (${start_ts} IS NULL OR s.ts + s.dur > ${start_ts})
  AND (${end_ts} IS NULL OR s.ts < ${end_ts})
  AND (
    s.name GLOB '*performCreate*'
    OR s.name GLOB '*performStart*'
    OR s.name GLOB '*performResume*'
    OR s.name GLOB '*performPause*'
    OR s.name GLOB '*performStop*'
    OR s.name GLOB '*performDestroy*'
    OR s.name GLOB '*activityStart*'
    OR s.name GLOB '*activityResume*'
  )
ORDER BY s.dur DESC
LIMIT 30
